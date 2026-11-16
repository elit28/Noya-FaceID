import AppKit

/// Référence à une app, transmissible entre fils (contrairement à `NSRunningApplication`).
struct AppReference: Sendable, Equatable {
    let pid: pid_t
    let bundleID: String?

    init(pid: pid_t, bundleID: String?) {
        self.pid = pid
        self.bundleID = bundleID
    }

    init?(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return nil }
        self.init(pid: app.processIdentifier, bundleID: app.bundleIdentifier)
    }

    @MainActor
    var runningApplication: NSRunningApplication? {
        NSRunningApplication(processIdentifier: pid)
    }
}

/// Repère l'apparition des apps protégées : lancement, activation, réaffichage, plus une
/// réconciliation toutes les 2 s qui rattrape un événement manqué et les apps déjà ouvertes.
/// Adapté de HeyMac (MIT, `AppLock/AppWatcher.swift`) ; aucune interrogation rapide.
@MainActor
final class AppWatcher {
    var isLocked: (String) -> Bool = { _ in false }
    var onCandidate: (NSRunningApplication) -> Void = { _ in }
    var onActivate: (NSRunningApplication) -> Void = { _ in }
    var onDeactivate: (AppReference) -> Void = { _ in }
    var onBackgroundLocked: (NSRunningApplication) -> Void = { _ in }
    var onTerminate: (AppReference) -> Void = { _ in }

    private var tokens: [NSObjectProtocol] = []
    private var timer: Timer?

    func start() {
        guard tokens.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        func observe(_ name: Notification.Name, _ handler: @escaping @MainActor (AppReference) -> Void) {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let reference = AppReference(note) else { return }
                MainActor.assumeIsolated { handler(reference) }
            })
        }
        observe(NSWorkspace.didActivateApplicationNotification) { [weak self] reference in
            guard let self, let app = reference.runningApplication else { return }
            self.onActivate(app)
            self.consider(app)
        }
        observe(NSWorkspace.didLaunchApplicationNotification) { [weak self] reference in
            guard let app = reference.runningApplication else { return }
            self?.consider(app)
        }
        observe(NSWorkspace.didUnhideApplicationNotification) { [weak self] reference in
            guard let app = reference.runningApplication else { return }
            self?.consider(app)
        }
        observe(NSWorkspace.didDeactivateApplicationNotification) { [weak self] reference in
            self?.onDeactivate(reference)
        }
        observe(NSWorkspace.didTerminateApplicationNotification) { [weak self] reference in
            self?.onTerminate(reference)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile() }
        }
        reconcile()
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        tokens.forEach { center.removeObserver($0) }
        tokens.removeAll()
        timer?.invalidate()
        timer = nil
    }

    private func reconcile() {
        let front = NSWorkspace.shared.frontmostApplication
        if let front { consider(front) }
        let me = ProcessInfo.processInfo.processIdentifier
        for app in NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier, isLocked(id), app.activationPolicy == .regular, !app.isTerminated,
                  app.processIdentifier != front?.processIdentifier, app.processIdentifier != me else { continue }
            onBackgroundLocked(app)
        }
    }

    private func consider(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier, isLocked(id),
              app.activationPolicy == .regular, !app.isTerminated else { return }
        onCandidate(app)
    }
}
