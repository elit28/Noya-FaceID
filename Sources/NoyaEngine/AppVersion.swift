import Foundation

/// Numéros de version « 1.2.3 » (un préfixe « v » et un suffixe « -beta » sont tolérés).
public enum AppVersion {
    /// Composantes numériques : « v1.2.3-beta » → [1, 2, 3]. Nil si illisible.
    public static func components(_ version: String) -> [Int]? {
        var text = version.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        if let dash = text.firstIndex(of: "-") { text = String(text[..<dash]) }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        return parts.compactMap { $0 }
    }

    /// `candidate` est-elle plus récente que `current` ? Une version illisible ne l'est jamais.
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let new = components(candidate), let old = components(current) else { return false }
        for index in 0..<max(new.count, old.count) {
            let a = index < new.count ? new[index] : 0
            let b = index < old.count ? old[index] : 0
            if a != b { return a > b }
        }
        return false
    }
}
