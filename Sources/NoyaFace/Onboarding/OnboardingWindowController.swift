import AppKit
import SwiftUI

/// Fenêtre de l'assistant de configuration, ouverte au premier lancement et depuis le menu.
@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
        window = nil
    }

    private func makeWindow() -> NSWindow {
        let view = OnboardingView(onFinish: { [weak self] in self?.close() })
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = String(localized: "Configuration de NOYA Face")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
