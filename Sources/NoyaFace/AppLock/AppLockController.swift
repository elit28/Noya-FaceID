import AppKit
import NoyaEngine

/// Protection d'applications : surveille les apps protégées et mène pour chacune un épisode
/// « bouclier + authentification ». Un épisode à la fois ; les autres apps attendent.
///
/// Corrections par rapport à HeyMac (MIT, `AppLock/AppLockController.swift`), voir l'audit §8.4 :
/// - l'app protégée est masquée (`hide`) dès le début de l'épisode, et à nouveau si elle
///   revient au premier plan (⌘⇥, Dock) : elle ne reçoit jamais le clavier sous le bouclier ;
/// - masque opaque par défaut ;
/// - Touch ID ou le mot de passe ne sont proposés qu'à la demande (maquette validée).
///
/// C'est une protection de confidentialité, pas une barrière de sécurité : l'app continue de
/// tourner et ses données restent lisibles sur le disque par d'autres moyens.
@MainActor
final class AppLockController {
    static let shared = AppLockController()

    let store = LockedAppStore()
    private let sessions = SessionBook()
    private let shield = ShieldController()
    private let watcher = AppWatcher()
    private let system = LocalSystemAuth()
    private var attempt: Task<Void, Never>?
    private var attemptID = UUID()
    private var activeApp: NSRunningApplication?
    private var queue: [NSRunningApplication] = []
    private var justActivatedPID: pid_t?
    /// Masquer l'app protégée fait passer une autre app au premier plan (souvent le Finder) :
    /// pendant ce court délai, cette activation ne doit pas retirer le bouclier.
    private var hideTransitionEnds: TimeInterval = 0
    private var running = false
    private var systemTokens: [NSObjectProtocol] = []
    private var distributedTokens: [NSObjectProtocol] = []

    private init() {}

    var isRunning: Bool { running }

    /// Fermeture de session, redémarrage ou extinction : NOYA Face quitte sans demander.
    private var quitAuthorized = false

    /// Mise à jour en un clic : l'app quitte puis la nouvelle version se relance aussitôt.
    func allowQuitForUpdate() {
        quitAuthorized = true
    }

    /// Quitter NOYA Face retire la protection : tant qu'elle est active, Touch ID ou le mot de
    /// passe sont demandés. Pendant un épisode, il faut d'abord le terminer.
    func shouldTerminate(_ application: NSApplication) -> NSApplication.TerminateReply {
        guard running, !quitAuthorized else { return .terminateNow }
        if activeApp != nil { return .terminateCancel }
        let system = self.system
        let reason = String(localized: "quitter NOYA Face et retirer la protection des applications")
        Task {
            let result = await system.authenticate(reason: reason)
            application.reply(toApplicationShouldTerminate: result == .success)
        }
        return .terminateLater
    }

    /// Démarre ou arrête la surveillance selon les réglages.
    func refresh() {
        if store.enabled && !store.apps.isEmpty {
            start()
        } else {
            stop()
        }
    }

    // MARK: - Cycle de vie

    private func start() {
        guard !running else { return }
        running = true
        shield.prepare()
        watcher.isLocked = { [store] in store.isLocked($0) }
        watcher.onCandidate = { [weak self] in self?.handleCandidate($0) }
        watcher.onActivate = { [weak self] app in
            guard let self else { return }
            if let id = app.bundleIdentifier, self.sessions.isUnlocked(id) { self.sessions.focusGained(id) }
            self.abandonEpisodeIfSwitchedAway(to: app)
        }
        watcher.onDeactivate = { [weak self] reference in
            guard let self, let id = reference.bundleID else { return }
            self.sessions.focusLost(id)
        }
        watcher.onBackgroundLocked = { [weak self] app in
            guard let self, let id = app.bundleIdentifier, !self.sessions.isUnlocked(id), !app.isHidden else { return }
            // Jamais les apps de l'épisode en cours ou en attente, ni une app qui démarre.
            let pid = app.processIdentifier
            if self.activeApp?.processIdentifier == pid || self.queue.contains(where: { $0.processIdentifier == pid }) { return }
            if let launched = app.launchDate, Date().timeIntervalSince(launched) < 5 { return }
            app.hide()
        }
        watcher.onTerminate = { [weak self] reference in self?.handleTerminate(reference) }
        watcher.start()
        observeSystemEvents()
    }

    private func stop() {
        guard running else { return }
        running = false
        watcher.stop()
        endEverything()
        sessions.revokeAll()
        let center = NSWorkspace.shared.notificationCenter
        systemTokens.forEach { center.removeObserver($0) }
        systemTokens.removeAll()
        distributedTokens.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        distributedTokens.removeAll()
    }

    // MARK: - Épisodes

    private func handleCandidate(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier, !sessions.isUnlocked(id) else { return }
        if let active = activeApp {
            if active.processIdentifier == app.processIdentifier {
                // ⌘⇥ ou clic dans le Dock pendant l'épisode : l'app ne doit pas garder le clavier.
                reclaimFocus()
            } else if !queue.contains(where: { $0.processIdentifier == app.processIdentifier }) {
                app.hide()
                queue.append(app)
            }
            return
        }
        begin(app)
    }

    private func begin(_ app: NSRunningApplication) {
        activeApp = app
        hideProtectedApp(app)
        let model = shield.model
        model.onUseSystem = { [weak self] in self?.useSystemAuthentication() }
        model.onRetry = { [weak self] in self?.startFaceRecognition() }
        model.onQuitApp = { [weak self] in self?.quitActiveApp() }
        shield.present(appName: app.localizedName ?? app.bundleIdentifier ?? AppInfo.name, icon: app.icon)
        NSApp.activate()
        startFaceRecognition()
    }

    private func reclaimFocus() {
        if let activeApp { hideProtectedApp(activeApp) }
        shield.focus()
        NSApp.activate()
    }

    private func hideProtectedApp(_ app: NSRunningApplication) {
        hideTransitionEnds = ProcessInfo.processInfo.systemUptime + 1
        app.hide()
    }

    private func startFaceRecognition() {
        guard let app = activeApp else { return }
        let id = UUID()
        attemptID = id
        attempt?.cancel()
        shield.model.phase = .scanning
        IslandController.shared.show(.searching)
        let seconds = TimeInterval(AppModel.shared.settings.scanSeconds)
        attempt = Task { [weak self] in
            guard let runtime = await AppModel.shared.loadRuntime() else {
                self?.finishFace(.unavailable, attempt: id, app: app)
                return
            }
            guard runtime.hasFaceProfile else {
                self?.finishFace(nil, attempt: id, app: app)
                return
            }
            let settings = AppModel.shared.settings
            let matcher = runtime.verifier(interactive: true, strictness: settings.strictness, distance: settings.detectionDistance)
            let result = await FaceVerifierAuthSource(matcher: matcher).authenticate(timeout: seconds)
            self?.finishFace(result, attempt: id, app: app)
        }
    }

    /// `result` vaut nil quand aucun visage n'est enregistré.
    private func finishFace(_ result: FaceAuthResult?, attempt id: UUID, app: NSRunningApplication) {
        guard !Task.isCancelled, attemptID == id, activeApp?.processIdentifier == app.processIdentifier else { return }
        switch result {
        case .matched:
            unlock(app, byFace: true)
        case .noMatch:
            shield.model.faceAvailable = true
            shield.model.phase = .refused(.notRecognized)
            IslandController.shared.flash(.refused, seconds: 1.6)
            let name = app.localizedName ?? AppInfo.name
            ActivityLog.shared.record(.refused, "\(name) : visage non reconnu")
        case .unavailable:
            shield.model.faceAvailable = true
            shield.model.phase = .refused(.unavailable)
            IslandController.shared.hide()
        case nil:
            shield.model.faceAvailable = false
            shield.model.phase = .refused(.noFace)
            IslandController.shared.hide()
        }
    }

    private func useSystemAuthentication() {
        guard let app = activeApp else { return }
        let id = UUID()
        attemptID = id
        attempt?.cancel()
        shield.model.phase = .system
        IslandController.shared.hide()
        let name = app.localizedName ?? AppInfo.name
        let reason = String(localized: "déverrouiller \(name)")
        let system = self.system
        attempt = Task { [weak self] in
            let result = await system.authenticate(reason: reason)
            guard let self, !Task.isCancelled, self.attemptID == id,
                  self.activeApp?.processIdentifier == app.processIdentifier else { return }
            switch result {
            case .success:
                self.unlock(app, byFace: false)
            case .cancelled:
                self.shield.model.phase = .refused(.cancelled)
            case .failed:
                self.shield.model.phase = .refused(.systemFailed)
            }
        }
    }

    private func unlock(_ app: NSRunningApplication, byFace: Bool) {
        let name = app.localizedName ?? AppInfo.name
        ActivityLog.shared.record(.success, byFace
            ? "\(name) déverrouillée par reconnaissance faciale"
            : "\(name) déverrouillée par Touch ID ou mot de passe")
        let id = attemptID
        shield.model.phase = .unlocked
        IslandController.shared.flash(.success)
        attempt = Task { [weak self] in
            // Laisse voir « Accès accordé » un instant.
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard let self, !Task.isCancelled, self.attemptID == id,
                  self.activeApp?.processIdentifier == app.processIdentifier else { return }
            if let bundleID = app.bundleIdentifier {
                self.sessions.unlock(bundleID, policy: self.store.app(bundleID)?.policy ?? .afterFocusLossMinutes(5))
            }
            self.shield.dismiss()
            app.unhide()
            self.justActivatedPID = app.processIdentifier
            _ = app.activate()
            self.endEpisode()
        }
    }

    private func quitActiveApp() {
        attempt?.cancel()
        IslandController.shared.hide()
        // Une feuille d'enregistrement ou une fenêtre ne doit pas apparaître après le bouclier.
        activeApp?.hide()
        _ = activeApp?.terminate()
        shield.dismiss()
        endEpisode()
    }

    private func endEpisode() {
        attemptID = UUID()
        attempt = nil
        activeApp = nil
        if !queue.isEmpty { begin(queue.removeFirst()) }
    }

    private func endEverything() {
        IslandController.shared.hide()
        attempt?.cancel()
        attempt = nil
        attemptID = UUID()
        activeApp = nil
        justActivatedPID = nil
        queue.removeAll()
        shield.dismiss()
    }

    /// L'utilisateur est passé à une autre app pendant l'épisode : le bouclier se retire pour
    /// qu'il puisse s'en servir. L'app protégée reste verrouillée et masquée ; y revenir
    /// relance un épisode. Seules les apps ordinaires comptent : la fenêtre système de
    /// Touch ID ne doit pas interrompre l'épisode.
    private func abandonEpisodeIfSwitchedAway(to app: NSRunningApplication) {
        if app.processIdentifier == justActivatedPID {
            justActivatedPID = nil
            return
        }
        guard let locked = activeApp, app.activationPolicy == .regular,
              app.processIdentifier != locked.processIdentifier,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        let lockedPID = locked.processIdentifier
        let otherPID = app.processIdentifier
        // Une activation passagère (lancement, masquage) ne doit pas retirer le bouclier.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, let current = self.activeApp, current.processIdentifier == lockedPID,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == otherPID else { return }
            if ProcessInfo.processInfo.systemUptime < self.hideTransitionEnds {
                // Activation provoquée par le masquage : le bouclier reprend le premier plan.
                self.shield.focus()
                NSApp.activate()
                return
            }
            self.attempt?.cancel()
            self.shield.dismiss()
            current.hide()
            self.endEpisode()
        }
    }

    private func handleTerminate(_ reference: AppReference) {
        if let id = reference.bundleID { sessions.revoke(id) }
        queue.removeAll { $0.processIdentifier == reference.pid }
        if activeApp?.processIdentifier == reference.pid {
            attempt?.cancel()
            shield.dismiss()
            endEpisode()
        }
    }

    // MARK: - Reverrouillage

    /// Mise en veille, verrouillage de l'écran et changement d'utilisateur reverrouillent
    /// toutes les apps (réglable).
    private func observeSystemEvents() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification,
        ]
        for name in names {
            systemTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.revokeAllIfEnabled() }
            })
        }
        systemTokens.append(center.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.quitAuthorized = true }
        })
        distributedTokens.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(SystemNotifications.screenIsLocked), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.revokeAllIfEnabled() }
        })
    }

    private func revokeAllIfEnabled() {
        guard AppLockKeys.isRelockOnSleepEnabled else { return }
        sessions.revokeAll()
        activeApp?.hide()
        endEverything()
    }
}
