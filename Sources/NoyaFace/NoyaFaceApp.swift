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

/// Délégué AppKit : assistant au premier lancement, et réouverture de l'app quand l'icône
/// de la barre des menus est masquée.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AppModel.shared.onboardingComplete {
            OnboardingWindowController.shared.show()
            return
        }
        if !PreferenceKeys.isMenuBarIconVisible {
            // Icône masquée : sans fenêtre, l'utilisateur n'aurait aucun moyen d'atteindre les réglages.
            SettingsWindowController.shared.show()
        }
        AppLockController.shared.refresh()
        AwayLockController.shared.refresh()
        if AppLockController.shared.isRunning || AwayLockController.shared.isEnabled || ScreenUnlockController.shared.isEnabled {
            // Préchargement des modèles : la première vérification se fait sans attente.
            Task {
                _ = await AppModel.shared.loadRuntime()
                await ScreenUnlockController.shared.refresh()
                if ScreenUnlockController.shared.isEnabled && ScreenUnlockController.shared.hasPassword {
                    // Toujours désarmé au lancement : Touch ID ou le mot de passe réarment.
                    await ScreenUnlockController.shared.arm()
                }
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppLockController.shared.shouldTerminate(sender)
    }

    /// Appelé quand l'utilisateur relance NOYA Face (Applications, Spotlight) alors qu'elle tourne déjà.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if AppModel.shared.onboardingComplete {
            SettingsWindowController.shared.show()
        } else {
            OnboardingWindowController.shared.show()
        }
        return true
    }
}
