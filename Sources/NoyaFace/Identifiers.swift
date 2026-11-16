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

/// Clés et identifiants système (valeurs documentées par Apple, non traduites).
enum SystemKeys {
    /// Valeur de `kAXTrustedCheckOptionPrompt` : utilisée telle quelle pour éviter l'accès à
    /// une variable globale C, interdit par la concurrence stricte de Swift 6.
    static let accessibilityPromptOption = "AXTrustedCheckOptionPrompt"
    /// Volet Confidentialité › Caméra de Réglages Système.
    static let cameraSettingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
}

/// Préférences des fonctions choisies dans l'assistant.
enum FeatureKeys {
    static let appProtection = "feature.appProtection"
    static let awayLock = "feature.awayLock"
}
