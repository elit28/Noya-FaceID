import AppKit
import SwiftUI

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value // noloc
    }
}

/// Panneau sans bordure couvrant un écran entier. Il passe au-dessus des fenêtres des apps
/// et du Dock, sous la barre des menus (maquette validée).
private final class ShieldPanel: NSPanel {
    init(screen: NSScreen, displayID: CGDirectDisplayID, model: ShieldModel) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        contentView = NSHostingView(rootView: ShieldView(model: model, displayID: displayID))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Un panneau par écran, créés à l'avance : afficher le bouclier se résume à les placer
/// devant, pour réduire le temps pendant lequel l'app protégée reste visible.
/// Adapté de HeyMac (MIT, `AppLock/ShieldController.swift`) : mode plein écran uniquement.
@MainActor
final class ShieldController {
    let model = ShieldModel()
    private(set) var isShowing = false
    private var panels: [CGDirectDisplayID: ShieldPanel] = [:]
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.syncPanels(orderFront: self.isShowing)
            }
        }
    }

    func prepare() {
        syncPanels(orderFront: false)
    }

    func present(appName: String, icon: NSImage?) {
        model.appName = appName
        model.icon = icon
        model.phase = .scanning
        let mouse = NSEvent.mouseLocation
        let primary = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        model.primaryDisplayID = primary?.displayID
        isShowing = true
        syncPanels(orderFront: true)
        focus()
    }

    /// Replace le bouclier devant et rend le clavier à sa carte.
    func focus() {
        guard isShowing else { return }
        for panel in panels.values { panel.orderFrontRegardless() }
        if let id = model.primaryDisplayID { panels[id]?.makeKey() }
    }

    func dismiss() {
        isShowing = false
        for panel in panels.values { panel.orderOut(nil) }
    }

    /// Crée les panneaux des nouveaux écrans, retire ceux des écrans débranchés et ajuste
    /// les autres.
    private func syncPanels(orderFront: Bool) {
        var seen = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let id = screen.displayID else { continue }
            seen.insert(id)
            let panel = panels[id] ?? ShieldPanel(screen: screen, displayID: id, model: model)
            panels[id] = panel
            panel.setFrame(screen.frame, display: true)
            if orderFront { panel.orderFrontRegardless() }
        }
        for id in panels.keys where !seen.contains(id) {
            panels[id]?.orderOut(nil)
            panels[id] = nil
        }
        // L'écran de la carte a pu être débranché : elle passe sur un écran présent.
        if isShowing, model.primaryDisplayID.map({ !seen.contains($0) }) ?? true,
           let id = NSScreen.main?.displayID ?? seen.first {
            model.primaryDisplayID = id
            panels[id]?.makeKey()
        }
    }
}
