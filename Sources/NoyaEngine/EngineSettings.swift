import Foundation

public enum MatchStrictness: String, CaseIterable, Sendable {
    case relaxed, normal, strict

    /// Seuils provisoires pour SFace (référence OpenCV : 0,363), à recalibrer par mesure
    /// sur Mac selon docs/tests/PROTOCOLE-RECONNAISSANCE.md.
    public var threshold: Float {
        switch self {
        case .relaxed: return 0.38
        case .normal: return 0.42
        case .strict: return 0.48
        }
    }

    public var title: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .normal: return "Normal"
        case .strict: return "Strict"
        }
    }
}

/// Distance de détection : largeur minimale du visage dans l'image.
public enum DetectionDistance: String, CaseIterable, Sendable {
    case close, standard, far

    public var minimumFaceWidthFraction: Double {
        switch self {
        case .close: return 0.22
        case .standard: return 0.15
        case .far: return 0.10
        }
    }
}

/// Non-secret preferences. Secrets (enrollment, login password) stay in SecureStore.
public final class EngineSettings: @unchecked Sendable {
    private enum Key {
        static let onboardingComplete = "onboardingComplete"
        static let setupComplete = "setupComplete"
        static let lockScreenEnabled = "lockScreenEnabled"
        static let paused = "paused"
        static let lockScreenNeedsPassword = "lockScreenNeedsPassword"
        static let strictness = "matchStrictness"
        static let launchAtLogin = "launchAtLogin"
        static let scanSeconds = "scanSeconds"
        static let detectionDistance = "detectionDistance"
        static let all = [onboardingComplete, setupComplete, lockScreenEnabled, paused, lockScreenNeedsPassword, strictness, launchAtLogin,
                          scanSeconds, detectionDistance]
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var onboardingComplete: Bool {
        get { defaults.object(forKey: Key.onboardingComplete) as? Bool ?? setupComplete }
        set { defaults.set(newValue, forKey: Key.onboardingComplete) }
    }

    public var setupComplete: Bool {
        get { defaults.bool(forKey: Key.setupComplete) }
        set { defaults.set(newValue, forKey: Key.setupComplete) }
    }

    public var lockScreenEnabled: Bool {
        get { defaults.bool(forKey: Key.lockScreenEnabled) }
        set { defaults.set(newValue, forKey: Key.lockScreenEnabled) }
    }

    public var paused: Bool {
        get { defaults.bool(forKey: Key.paused) }
        set { defaults.set(newValue, forKey: Key.paused) }
    }

    /// Set when a typed password left the screen locked; auto-typing stays off until the
    /// user saves the password again.
    public var lockScreenNeedsPassword: Bool {
        get { defaults.bool(forKey: Key.lockScreenNeedsPassword) }
        set { defaults.set(newValue, forKey: Key.lockScreenNeedsPassword) }
    }

    public var strictness: MatchStrictness {
        get { MatchStrictness(rawValue: defaults.string(forKey: Key.strictness) ?? "") ?? .normal }
        set { defaults.set(newValue.rawValue, forKey: Key.strictness) }
    }

    public var launchAtLogin: Bool {
        get { defaults.object(forKey: Key.launchAtLogin) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    /// Durées de recherche du visage proposées à l'utilisateur, en secondes.
    public static let scanSecondsRange = 2...10

    /// Durée maximale d'une recherche du visage (5 s par défaut). Au-delà, la caméra
    /// s'éteint et Touch ID ou le mot de passe est proposé.
    public var scanSeconds: Int {
        get {
            let stored = defaults.object(forKey: Key.scanSeconds) as? Int ?? 5
            return min(max(stored, Self.scanSecondsRange.lowerBound), Self.scanSecondsRange.upperBound)
        }
        set {
            defaults.set(min(max(newValue, Self.scanSecondsRange.lowerBound), Self.scanSecondsRange.upperBound), forKey: Key.scanSeconds)
        }
    }

    public var detectionDistance: DetectionDistance {
        get { DetectionDistance(rawValue: defaults.string(forKey: Key.detectionDistance) ?? "") ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: Key.detectionDistance) }
    }

    public func resetAll() {
        Key.all.forEach { defaults.removeObject(forKey: $0) }
    }
}
