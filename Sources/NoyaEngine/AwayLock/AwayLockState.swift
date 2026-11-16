import Foundation

/// Réglages du verrouillage en cas d'absence.
public struct AwayLockConfig: Equatable, Sendable {
    /// Inactivité (ni clavier ni souris) avant la première vérification de présence.
    public var idleDelay: TimeInterval
    /// Délai entre deux vérifications quand le visage n'a pas été reconnu.
    public var retryInterval: TimeInterval
    /// Vérifications consécutives sans visage reconnu avant le verrouillage.
    public var missesBeforeLock: Int

    public init(idleDelay: TimeInterval = 120, retryInterval: TimeInterval = 15, missesBeforeLock: Int = 2) {
        self.idleDelay = idleDelay
        self.retryInterval = retryInterval
        self.missesBeforeLock = max(1, missesBeforeLock)
    }

    /// Délais d'absence proposés à l'utilisateur, en minutes.
    public static let idleDelayChoices = [1, 2, 5, 10]
}

/// Résultat d'une vérification de présence.
public enum PresenceCheck: Equatable, Sendable {
    /// Votre visage a été reconnu.
    case present
    /// Aucun visage reconnu (personne, ou une autre personne).
    case absent
    /// Vérification impossible (caméra occupée ou absente, Mac fermé) : ni présence ni absence.
    case inconclusive
}

public enum AwayLockDecision: Equatable, Sendable {
    /// Rien à faire avant ce délai (secondes).
    case wait(TimeInterval)
    /// Vérifier maintenant la présence.
    case check
    /// Verrouiller le Mac.
    case lock
}

/// Décide quand allumer brièvement la caméra et quand verrouiller, à partir du temps
/// d'inactivité du système. La caméra n'est jamais allumée tant que l'utilisateur tape ou
/// bouge la souris ; après une présence confirmée, la vérification suivante attend de
/// nouveau tout le délai d'inactivité.
public struct AwayLockState: Equatable, Sendable {
    public let config: AwayLockConfig
    public private(set) var misses = 0
    /// Moment de la prochaine vérification, exprimé en temps d'inactivité.
    private var nextCheckAt: TimeInterval?

    public init(config: AwayLockConfig) {
        self.config = config
    }

    public mutating func next(idle: TimeInterval) -> AwayLockDecision {
        if idle < config.idleDelay {
            reset()
            return .wait(config.idleDelay - idle)
        }
        if misses >= config.missesBeforeLock { return .lock }
        let due = nextCheckAt ?? config.idleDelay
        return idle >= due ? .check : .wait(due - idle)
    }

    /// Enregistre le résultat d'une vérification faite à `idle` secondes d'inactivité.
    public mutating func record(_ check: PresenceCheck, idle: TimeInterval) {
        switch check {
        case .present:
            misses = 0
            nextCheckAt = idle + config.idleDelay
        case .absent:
            misses += 1
            nextCheckAt = idle + config.retryInterval
        case .inconclusive:
            nextCheckAt = idle + config.retryInterval
        }
    }

    /// Activité de l'utilisateur, ou Mac verrouillé : tout recommence.
    public mutating func reset() {
        misses = 0
        nextCheckAt = nil
    }
}
