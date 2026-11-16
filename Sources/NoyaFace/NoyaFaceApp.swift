import AppKit
import SwiftUI

/// Point d'entrée de NOYA Face : une application de barre des menus (LSUIElement).
@main
struct NoyaFaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(PreferenceKeys.menuBarIconVisible) private var menuBarIconVisible = true

    var body: some Scene {
        MenuBarExtra(isInserted: $menuBarIconVisible) {
            MenuContent()
        } label: {
            Image(nsImage: BrandMark.menuBarImage())
                .accessibilityLabel(Text(verbatim: AppInfo.name))
        }
    }
}

/// Délégué AppKit : gère la réouverture de l'app quand l'icône de la barre des menus est masquée.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Icône masquée : sans fenêtre, l'utilisateur n'aurait aucun moyen d'atteindre les réglages.
        if !PreferenceKeys.isMenuBarIconVisible {
            SettingsWindowController.shared.show()
        }
    }

    /// Appelé quand l'utilisateur relance NOYA Face (Applications, Spotlight) alors qu'elle tourne déjà.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }
}
