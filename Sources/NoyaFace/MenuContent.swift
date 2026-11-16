import AppKit
import SwiftUI

/// Contenu du menu de la barre des menus.
struct MenuContent: View {
    @AppStorage(PreferenceKeys.menuBarIconVisible) private var menuBarIconVisible = true

    var body: some View {
        Text("Version de développement")
        Divider()
        Button("Réglages…") {
            SettingsWindowController.shared.show()
        }
        .keyboardShortcut(",")
        Button("Masquer l’icône de la barre des menus") {
            menuBarIconVisible = false
            // La fenêtre explique comment retrouver NOYA Face une fois l'icône masquée.
            SettingsWindowController.shared.show()
        }
        Divider()
        Button("Quitter NOYA Face") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
