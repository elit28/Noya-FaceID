import AppKit
import Foundation
import NoyaEngine
import Observation

/// Recherche de mises à jour : une requête HTTPS vers l'API publique de GitHub, sans aucune
/// donnée personnelle. Désactivée par défaut. Rien n'est installé automatiquement :
/// l'utilisateur télécharge lui-même la nouvelle version depuis la page de publication.
@MainActor
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, page: URL)
        case failed
    }

    private(set) var state: State = .idle

    private init() {}

    var isAutomatic: Bool { UserDefaults.standard.bool(forKey: UpdateKeys.automatic) }

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
                state = .failed
                return
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            if AppVersion.isNewer(release.tagName, than: AppInfo.version), let page = URL(string: release.htmlURL) {
                state = .available(version: release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV")), page: page) // noloc
            } else {
                state = .upToDate
            }
        } catch {
            state = .failed
        }
    }

    func openDownloadPage() {
        if case .available(_, let page) = state {
            NSWorkspace.shared.open(page)
        }
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name" // noloc
            case htmlURL = "html_url" // noloc
        }
    }
}
