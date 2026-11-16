import AppKit
import SwiftUI

/// Fenêtre des réglages gérée par AppKit : elle peut être ouverte depuis le menu comme
/// depuis le délégué de l'application (relance alors que l'icône est masquée).
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        AppPresence.present(window)
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = AppInfo.name
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 900, height: 680))
        window.contentMinSize = NSSize(width: 820, height: 600)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
