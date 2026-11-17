import CryptoKit
import Foundation

public enum UpdateError: Error, Equatable {
    case assetMissing
    case checksumMissing
    case checksumMismatch
    case wrongBundle
    case wrongVersion
    case signatureInvalid
    case notWritable
    case extractionFailed
}

/// Vérifications d'une mise à jour téléchargée, avant de remplacer l'app : empreinte SHA-256
/// publiée avec la version, identifiant et numéro de version de l'app extraite.
public enum UpdatePackage {
    /// Nom de l'archive publiée pour une version (« NOYA-Face-1.0.3.zip »).
    public static func archiveName(version: String) -> String {
        "NOYA-Face-\(version).zip"
    }

    /// Nom du fichier d'empreintes publié pour une version.
    public static func checksumName(version: String) -> String {
        "NOYA-Face-\(version).sha256"
    }

    /// Lit un fichier au format de `shasum -a 256` : « <empreinte>  <fichier> » par ligne.
    public static func parseChecksums(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let hash = parts[0].lowercased()
            let name = parts[1].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "*"))
            guard hash.count == 64, hash.allSatisfy(\.isHexDigit), !name.isEmpty else { continue }
            result[name] = hash
        }
        return result
    }

    /// Empreinte SHA-256 d'un fichier, lue par blocs (l'archive fait une vingtaine de Mo).
    public static func sha256Hex(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func verifyChecksum(of file: URL, named name: String, checksums: [String: String]) throws {
        guard let expected = checksums[name] else { throw UpdateError.checksumMissing }
        guard try sha256Hex(of: file) == expected else { throw UpdateError.checksumMismatch }
    }

    /// L'app extraite doit être NOYA Face, dans la version annoncée.
    public static func validateBundle(at app: URL, bundleID: String, version: String) throws {
        let plist = app.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { throw UpdateError.wrongBundle }
        guard info["CFBundleIdentifier"] as? String == bundleID else { throw UpdateError.wrongBundle }
        guard info["CFBundleShortVersionString"] as? String == version else { throw UpdateError.wrongVersion }
    }
}
