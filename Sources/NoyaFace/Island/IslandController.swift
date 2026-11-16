import AppKit
import SwiftUI

/// Fenêtre de l'île autour de l'encoche : panneau transparent, sans clic, au-dessus de la
/// barre des menus et du bouclier, sur tous les espaces. API publiques uniquement : l'île
/// n'apparaît pas sur l'écran verrouillé (il faudrait des API privées de macOS).
@MainActor
final class IslandController {
    static let shared = IslandController()

    let model = IslandModel()
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?
    private var screenObserver: NSObjectProtocol?

    private init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
    }

    /// Affiche un état jusqu'au prochain appel.
    func show(_ state: IslandState) {
        guard IslandKeys.isEnabled else { return }
        hideTask?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        model.style = IslandStyle(rawValue: UserDefaults.standard.string(forKey: IslandKeys.style) ?? "") ?? .sides
        reposition()
        panel.orderFrontRegardless()
        if state == .refused && model.state != .refused { model.shakes += 1 }
        model.state = state
        model.expanded = true
    }

    /// Affiche un état puis replie l'île (réussite : 1,2 s, comme la maquette).
    func flash(_ state: IslandState, seconds: Double = 1.2) {
        show(state)
        scheduleHide(after: seconds)
    }

    func hide() {
        scheduleHide(after: 0)
    }

    private func scheduleHide(after seconds: Double) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.model.expanded = false
            // Laisse le repli se terminer avant de retirer la fenêtre.
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            self.model.state = nil
            self.panel?.orderOut(nil)
        }
    }

    private func reposition() {
        guard let panel, let screen = IslandGeometry.preferredScreen else { return }
        let geometry = IslandGeometry.measure(screen)
        model.geometry = geometry
        let width: CGFloat
        let height: CGFloat
        if geometry.hasNotch {
            width = geometry.notch.width + IslandMetrics.sidesWing * 2 + IslandMetrics.ear * 2
            height = geometry.notch.height
        } else {
            width = IslandMetrics.pillSize.width + 20
            height = geometry.menuBarHeight + IslandMetrics.pillGap + IslandMetrics.pillSize.height
        }
        panel.setFrame(NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height),
                       display: true)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 40),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        // Au-dessus de la barre des menus et du bouclier des apps protégées.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.contentView = NSHostingView(rootView: IslandView(model: model))
        return panel
    }
}
