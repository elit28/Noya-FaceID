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
        AppPresence.present(window)
    }

    /// Ouvre l'assistant directement à l'étape « Visage » (réenregistrement depuis les réglages).
    func showEnrollment() {
        close()
        let window = makeWindow(startStep: .face)
        self.window = window
        AppPresence.present(window)
    }

    func close() {
        window?.close()
        window = nil
    }

    private func makeWindow(startStep: OnboardingView.Step = .welcome) -> NSWindow {
        let view = OnboardingView(startStep: startStep, onFinish: { [weak self] in self?.close() })
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = String(localized: "Configuration de NOYA Face")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
