import AppKit
import SwiftUI

/// Contenu du menu de la barre des menus.
struct MenuContent: View {
    @AppStorage(PreferenceKeys.menuBarIconVisible) private var menuBarIconVisible = true
    @State private var unlock = ScreenUnlockController.shared

    var body: some View {
        Text("Version \(AppInfo.version)")
        Divider()
        if unlock.isEnabled && unlock.hasPassword && unlock.armedUntil == nil {
            // Désarmé (redémarrage, délai écoulé) : un clic et Touch ID pour réarmer.
            Button("Armer le déverrouillage de l’écran…") {
                Task { await ScreenUnlockController.shared.arm() }
            }
            Divider()
        }
        Button("Réglages…") {
            SettingsWindowController.shared.show()
        }
        .keyboardShortcut(",")
        Button("Assistant de configuration…") {
            OnboardingWindowController.shared.show()
        }
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
