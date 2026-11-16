import Foundation

// Identifiants techniques, jamais affichés à l'utilisateur.
// Ce fichier est exclu du contrôle de traduction (scripts/check-localizations.py).

/// Clés des préférences de l'application (UserDefaults).
enum PreferenceKeys {
    static let menuBarIconVisible = "menuBarIconVisible"

    /// Valeur par défaut : l'icône est visible.
    static var isMenuBarIconVisible: Bool {
        UserDefaults.standard.object(forKey: menuBarIconVisible) as? Bool ?? true
    }
}

/// Informations sur l'application lues dans Info.plist.
enum AppInfo {
    /// Nom de marque, identique dans toutes les langues.
    static let name = "NOYA Face"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}
