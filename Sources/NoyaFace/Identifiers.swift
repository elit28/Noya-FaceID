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
    /// Même clé que `LockedAppStore.enabled` : l'assistant active directement la protection.
    static let appProtection = "appLock.enabled"
    static let awayLock = "feature.awayLock"
}

/// Préférences de la protection d'applications.
enum AppLockKeys {
    /// Aspect du bouclier : `ShieldMask`.
    static let mask = "appLock.mask"
    /// Reverrouiller toutes les apps à la mise en veille et au verrouillage du Mac.
    static let relockOnSleep = "appLock.relockOnSleep"

    /// Suggestions du sélecteur : Messages, Notes, Photos, Mail.
    static let suggestedBundleIDs = ["com.apple.MobileSMS", "com.apple.Notes", "com.apple.Photos", "com.apple.mail"]
    /// Dossier proposé par « Autre application… ».
    static let applicationsFolder = "/Applications"

    static var isRelockOnSleepEnabled: Bool {
        UserDefaults.standard.object(forKey: relockOnSleep) as? Bool ?? true
    }
}

/// Aspect du bouclier. Opaque par défaut : rien de l'app n'est visible.
enum ShieldMask: String, CaseIterable {
    case opaque
    case blur
}

/// Notification système non documentée, émise au verrouillage de l'écran. Une imitation
/// ne peut que reverrouiller les apps : aucun risque à l'écouter.
enum SystemNotifications {
    static let screenIsLocked = "com.apple.screenIsLocked"
}
