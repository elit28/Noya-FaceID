import AppKit
import CoreGraphics
import NoyaCore
import NoyaEngine

/// Verrouillage en cas d'absence : tant que le clavier ou la souris servent, rien ne se passe.
/// Après le délai d'inactivité choisi, la caméra s'allume brièvement (le voyant vert
/// s'allume aussi) ; si votre visage n'est pas reconnu deux fois de suite, le Mac est
/// verrouillé avec le raccourci système ⌃⌘Q.
@MainActor
final class AwayLockController {
    static let shared = AwayLockController()

    private var loop: Task<Void, Never>?

    private init() {}

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: FeatureKeys.awayLock) }

    func refresh() {
        if isEnabled && AppModel.shared.onboardingComplete {
            guard loop == nil else { return }
            loop = Task { [weak self] in await self?.run() }
        } else {
            loop?.cancel()
            loop = nil
        }
    }

    private static func currentConfig() -> AwayLockConfig {
        let stored = UserDefaults.standard.object(forKey: AwayLockKeys.idleMinutes) as? Int ?? 2
        let minutes = AwayLockConfig.idleDelayChoices.contains(stored) ? stored : 2
        return AwayLockConfig(idleDelay: TimeInterval(minutes * 60))
    }

    private func run() async {
        var state = AwayLockState(config: Self.currentConfig())
        while !Task.isCancelled {
            let config = Self.currentConfig()
            if config != state.config { state = AwayLockState(config: config) }
            var pause: TimeInterval = 30
            if canCheckNow() {
                let idle = ScreenLocker.systemIdleSeconds()
                switch state.next(idle: idle) {
                case .wait(let seconds):
                    // Plafonné pour suivre un changement de réglage sans attendre.
                    pause = min(max(seconds, 1), 30)
                case .check:
                    let presence = await checkPresence()
                    state.record(presence, idle: idle)
                    pause = 1
                case .lock:
                    lockScreen()
                    state.reset()
                    pause = 10
                }
            } else {
                state.reset()
            }
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
        }
    }

    /// Jamais de caméra quand le verrouillage est impossible, l'écran déjà verrouillé ou
    /// l'écran en veille.
    private func canCheckNow() -> Bool {
        guard ScreenLocker.canLock else { return false }
        guard isScreenLocked() == false else { return false }
        return CGDisplayIsAsleep(CGMainDisplayID()) == 0
    }

    private func checkPresence() async -> PresenceCheck {
        guard let runtime = await AppModel.shared.loadRuntime(), runtime.hasFaceProfile else { return .inconclusive }
        let matcher = runtime.presenceVerifier(strictness: AppModel.shared.settings.strictness)
        let outcome = await Task.detached(priority: .utility) {
            // S'arrête dès que l'utilisateur reprend la souris ou le clavier.
            matcher.run(timeout: 2.5, requiredConsecutive: 2, waitForTurn: 0,
                        keepGoing: { ScreenLocker.systemIdleSeconds() > 1 })
        }.value
        if outcome.matched { return .present }
        return outcome.failure == nil ? .absent : .inconclusive
    }

    private func lockScreen() {
        do {
            try ScreenLocker.lock()
            AppLog.shared.write("away lock: screen locked after absence") // noloc
        } catch {
            AppLog.shared.write("away lock: lock failed (\(error))") // noloc
        }
    }
}
