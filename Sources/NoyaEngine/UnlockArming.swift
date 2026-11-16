import Foundation

/// Fenêtre pendant laquelle NOYA Face a le droit de taper votre mot de passe sur l'écran
/// verrouillé. On l'arme avec Touch ID ou le mot de passe macOS (vérifiés par macOS) ; elle
/// expire après la durée choisie et n'existe qu'en mémoire : un redémarrage du Mac ou une
/// relance de l'app désarme toujours. Plusieurs visages inconnus refusés désarment aussi.
public final class UnlockArming: @unchecked Sendable {
    /// Durées d'armement proposées, en heures.
    public static let durationChoices = [8, 24, 72, 168]
    public static let defaultHours = 24
    /// Visages inconnus refusés sur l'écran verrouillé avant de désarmer.
    public static let rejectionsBeforeDisarm = 4

    private let now: () -> TimeInterval
    private let lock = NSLock()
    private var armedUntil: TimeInterval?
    private var rejections = 0

    /// `now` doit continuer d'avancer pendant la veille du Mac (horloge monotone).
    public init(now: @escaping () -> TimeInterval = UnlockArming.monotonicSeconds) {
        self.now = now
    }

    public static func monotonicSeconds() -> TimeInterval {
        // CLOCK_MONOTONIC continue d'avancer pendant la veille (man clock_gettime).
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1_000_000_000
    }

    public func arm(hours: Int) {
        lock.withLock {
            armedUntil = now() + TimeInterval(max(1, hours)) * 3600
            rejections = 0
        }
    }

    public func disarm() {
        lock.withLock {
            armedUntil = nil
            rejections = 0
        }
    }

    public var isArmed: Bool {
        lock.withLock {
            guard let until = armedUntil else { return false }
            if now() >= until {
                armedUntil = nil
                return false
            }
            return true
        }
    }

    /// Secondes restantes, ou nil si désarmé.
    public var remaining: TimeInterval? {
        lock.withLock {
            guard let until = armedUntil else { return nil }
            let left = until - now()
            return left > 0 ? left : nil
        }
    }

    /// Un visage qui n'est pas le vôtre a été vu sur l'écran verrouillé. Retourne true si
    /// la saisie automatique vient d'être désarmée.
    @discardableResult
    public func recordRejectedFace() -> Bool {
        lock.withLock {
            guard armedUntil != nil else { return false }
            rejections += 1
            guard rejections >= Self.rejectionsBeforeDisarm else { return false }
            armedUntil = nil
            rejections = 0
            return true
        }
    }

    /// Déverrouillage réussi : le compteur d'échecs repart de zéro.
    public func recordUnlock() {
        lock.withLock { rejections = 0 }
    }
}
