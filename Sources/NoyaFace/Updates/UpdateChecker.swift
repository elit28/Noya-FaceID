import AppKit
import Foundation
import NoyaEngine
import Observation

/// Mises à jour : recherche (une requête HTTPS vers l'API publique de GitHub, sans donnée
/// personnelle, automatique seulement si l'utilisateur l'active), puis installation en un clic.
/// Avant de remplacer l'app, la mise à jour est vérifiée : empreinte SHA-256 publiée avec la
/// version, identifiant et numéro de version, signature de code intacte. Au moindre écart,
/// rien n'est modifié et l'utilisateur peut la télécharger depuis GitHub.
@MainActor
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    enum Failure: Equatable {
        case network
        case verification
        case notWritable
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case downloading(version: String)
        case installing(version: String)
        case failed(Failure)
    }

    private(set) var state: State = .idle
    private var latest: Release?

    private init() {}

    var isAutomatic: Bool { UserDefaults.standard.bool(forKey: UpdateKeys.automatic) }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    /// Au lancement : au plus une recherche par jour, seulement si l'utilisateur l'a activée.
    func checkIfDue() async {
        guard isAutomatic else { return }
        let last = UserDefaults.standard.object(forKey: UpdateKeys.lastCheck) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 24 * 3600 else { return }
        await check()
    }

    func check() async {
        guard let url = URL(string: AppInfo.latestReleaseAPI) else { return }
        state = .checking
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept") // noloc
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            UserDefaults.standard.set(Date(), forKey: UpdateKeys.lastCheck)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 404 {
                // Aucune version publiée hors pré-versions.
                state = .upToDate
                return
            }
            guard status == 200 else {
                state = .failed(.network)
                return
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            latest = release
            if AppVersion.isNewer(release.tagName, than: AppInfo.version) {
                state = .available(version: release.version)
            } else {
                state = .upToDate
            }
        } catch {
            state = .failed(.network)
        }
    }

    /// Page de la version sur GitHub (nouveautés, téléchargement manuel).
    func openReleasePage() {
        if let page = latest.flatMap({ URL(string: $0.htmlURL) }) {
            NSWorkspace.shared.open(page)
        } else if let releases = URL(string: AppInfo.repositoryURL + "/releases/latest") { // noloc
            NSWorkspace.shared.open(releases)
        }
    }

    /// Télécharge, vérifie, remplace l'app puis la relance.
    func installUpdate() async {
        guard case .available(let version) = state, let release = latest else { return }
        let current = Bundle.main.bundleURL
        guard current.pathExtension == "app", // noloc
              FileManager.default.isWritableFile(atPath: current.deletingLastPathComponent().path) else {
            state = .failed(.notWritable)
            return
        }
        guard let archiveURL = release.assetURL(named: UpdatePackage.archiveName(version: version)),
              let checksumURL = release.assetURL(named: UpdatePackage.checksumName(version: version)) else {
            state = .failed(.verification)
            return
        }

        state = .downloading(version: version)
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("noya-face-update-\(UUID().uuidString)", isDirectory: true) // noloc
        do {
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let (checksumData, _) = try await URLSession.shared.data(from: checksumURL)
            let checksums = UpdatePackage.parseChecksums(String(decoding: checksumData, as: UTF8.self))
            let (downloaded, _) = try await URLSession.shared.download(from: archiveURL)
            let archive = work.appendingPathComponent(UpdatePackage.archiveName(version: version))
            try FileManager.default.moveItem(at: downloaded, to: archive)

            state = .installing(version: version)
            let bundleID = Bundle.main.bundleIdentifier ?? ""
            let newApp = try await Task.detached(priority: .userInitiated) {
                try Self.prepare(archive: archive, checksums: checksums, version: version, bundleID: bundleID, work: work)
            }.value
            do {
                _ = try FileManager.default.replaceItemAt(current, withItemAt: newApp)
            } catch {
                throw UpdateError.notWritable
            }
            relaunch(current)
        } catch UpdateError.notWritable {
            state = .failed(.notWritable)
        } catch is UpdateError {
            state = .failed(.verification)
        } catch {
            state = .failed(.network)
        }
        try? FileManager.default.removeItem(at: work)
    }

    /// Hors du fil principal : empreinte, extraction, identité de l'app, signature.
    nonisolated private static func prepare(archive: URL, checksums: [String: String], version: String,
                                            bundleID: String, work: URL) throws -> URL {
        try UpdatePackage.verifyChecksum(of: archive, named: archive.lastPathComponent, checksums: checksums)
        let extracted = work.appendingPathComponent("extrait", isDirectory: true) // noloc
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
        guard run("/usr/bin/ditto", ["-x", "-k", archive.path, extracted.path]) else { // noloc
            throw UpdateError.extractionFailed
        }
        let app = extracted.appendingPathComponent("NOYA Face.app") // noloc
        try UpdatePackage.validateBundle(at: app, bundleID: bundleID, version: version)
        guard run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path]) else { // noloc
            throw UpdateError.signatureInvalid
        }
        return app
    }

    nonisolated private static func run(_ tool: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Relance la nouvelle version dès que celle-ci a quitté.
    private func relaunch(_ app: URL) {
        let pid = String(ProcessInfo.processInfo.processIdentifier)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh") // noloc
        process.arguments = ["-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$2\"", // noloc
                             "sh", pid, app.path] // noloc
        try? process.run()
        AppLockController.shared.allowQuitForUpdate()
        NSApplication.shared.terminate(nil)
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: String
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: String

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url" // noloc
            }
        }

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name" // noloc
            case htmlURL = "html_url" // noloc
            case assets
        }

        var version: String { tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV")) } // noloc

        func assetURL(named name: String) -> URL? {
            assets.first { $0.name == name }.flatMap { URL(string: $0.browserDownloadURL) }
        }
    }
}
