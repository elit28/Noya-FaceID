import Foundation
import NoyaEngine
import Observation

/// Déverrouillage de l'écran (mode avancé, désactivé par défaut) : quand l'écran est
/// verrouillé et votre visage reconnu, NOYA Face tape votre mot de passe macOS à votre place.
/// Ce n'est pas une authentification système : c'est une saisie automatique, armée par
/// Touch ID ou votre mot de passe pour une durée limitée.
@MainActor
@Observable
final class ScreenUnlockController {
    static let shared = ScreenUnlockController()

    enum SaveResult: Equatable {
        case saved
        case invalid
        case unavailable(String)
        case failed
    }

    let arming = UnlockArming()
    /// Fin de l'armement, pour l'affichage.
    private(set) var armedUntil: Date?
    private(set) var hasPassword = false
    /// Le dernier mot de passe tapé a été refusé par macOS (changé depuis ?).
    private(set) var passwordRejected = false
    private(set) var disarmedAfterRejections = false
    private var engine: EngineController?
    private var expiryTask: Task<Void, Never>?

    private init() {}

    private var settings: EngineSettings { AppModel.shared.settings }

    var isEnabled: Bool { settings.lockScreenEnabled }

    var armHours: Int {
        let stored = UserDefaults.standard.object(forKey: ScreenUnlockKeys.armHours) as? Int ?? UnlockArming.defaultHours
        return UnlockArming.durationChoices.contains(stored) ? stored : UnlockArming.defaultHours
    }

    /// Démarre ou arrête la surveillance de l'écran verrouillé selon les réglages.
    func refresh() async {
        passwordRejected = settings.lockScreenNeedsPassword
        guard AppModel.shared.onboardingComplete, settings.lockScreenEnabled,
              let runtime = await AppModel.shared.loadRuntime() else {
            stopEngine()
            return
        }
        hasPassword = runtime.hasLoginPassword
        guard hasPassword else {
            stopEngine()
            return
        }
        guard engine == nil else { return }
        let arming = self.arming
        let engine = EngineController(
            runtime: runtime, settings: settings,
            isArmed: { @Sendable in arming.isArmed },
            onEvent: { @Sendable event in
                Task { @MainActor in ScreenUnlockController.shared.handle(event) }
            }
        )
        do {
            try engine.start()
            self.engine = engine
        } catch {
            AppLog.shared.write("screen unlock: engine failed to start (\(error))") // noloc
        }
    }

    private func stopEngine() {
        engine?.stop()
        engine = nil
    }

    private func handle(_ event: EngineEvent) {
        switch event {
        case .lockScreenUnlocked:
            arming.recordUnlock()
            IslandController.shared.flash(.unlocking, seconds: 1.6)
            ActivityLog.shared.record(.success, "Écran déverrouillé par reconnaissance faciale")
        case .lockScreenNoMatch:
            ActivityLog.shared.record(.refused, "Visage inconnu sur l’écran verrouillé")
            if arming.recordRejectedFace() {
                disarmedAfterRejections = true
                updateArmedUntil()
            }
        case .lockScreenPasswordRejected:
            passwordRejected = true
        default:
            break
        }
    }

    // MARK: - Mot de passe

    /// Vérifie le mot de passe auprès de macOS, puis l'enregistre chiffré.
    func savePassword(_ password: String) async -> SaveResult {
        let check = await Task.detached(priority: .userInitiated) { LoginPasswordVerifier.verify(password) }.value
        switch check {
        case .invalid:
            return .invalid
        case .unavailable(let message):
            return .unavailable(message)
        case .valid:
            break
        }
        guard let runtime = await AppModel.shared.loadRuntime() else { return .failed }
        let saved = await Task.detached(priority: .userInitiated) { (try? runtime.saveLoginPassword(password)) != nil }.value
        guard saved else { return .failed }
        settings.lockScreenNeedsPassword = false
        passwordRejected = false
        hasPassword = true
        return .saved
    }

    // MARK: - Activation et armement

    func enable() async {
        settings.lockScreenEnabled = true
        await refresh()
    }

    /// Désactiver supprime aussi le mot de passe enregistré : il n'a plus de raison d'exister.
    func disable() async {
        settings.lockScreenEnabled = false
        disarm()
        stopEngine()
        if let runtime = await AppModel.shared.loadRuntime() {
            try? runtime.removeLoginPassword()
            hasPassword = runtime.hasLoginPassword
        }
    }

    /// Touch ID ou le mot de passe macOS, vérifiés par macOS, arment la saisie automatique.
    @discardableResult
    func arm() async -> Bool {
        let result = await LocalSystemAuth().authenticate(reason: String(localized: "autoriser la saisie automatique de votre mot de passe sur l’écran verrouillé"))
        guard result == .success else { return false }
        arming.arm(hours: armHours)
        disarmedAfterRejections = false
        updateArmedUntil()
        return true
    }

    func disarm() {
        arming.disarm()
        updateArmedUntil()
    }

    private func updateArmedUntil() {
        expiryTask?.cancel()
        guard let remaining = arming.remaining else {
            armedUntil = nil
            return
        }
        armedUntil = Date().addingTimeInterval(remaining)
        expiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.updateArmedUntil()
        }
    }
}
