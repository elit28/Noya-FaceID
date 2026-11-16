import AppKit

/// Comme les autres apps : tant qu'une fenêtre de NOYA Face est ouverte, icône dans le Dock et
/// menus de NOYA Face dans la barre des menus. Sans fenêtre, l'app redevient discrète (icône
/// dans la barre des menus seulement).
@MainActor
enum AppPresence {
    private static var closeObservers: [ObjectIdentifier: NSObjectProtocol] = [:]
    private static let menuActions = MainMenuActions()

    /// Affiche la fenêtre au premier plan et passe l'app en mode « app ordinaire ».
    static func present(_ window: NSWindow) {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
            NSApp.mainMenu = makeMainMenu()
        }
        let id = ObjectIdentifier(window)
        if closeObservers[id] == nil {
            closeObservers[id] = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { _ in
                MainActor.assumeIsolated { windowClosed(id) }
            }
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private static func windowClosed(_ id: ObjectIdentifier) {
        if let token = closeObservers.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(token)
        }
        if closeObservers.isEmpty {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Menus

    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let app = NSMenu(title: AppInfo.name)
        app.addItem(item(String(localized: "À propos de NOYA Face"),
                         #selector(NSApplication.orderFrontStandardAboutPanel(_:)), key: ""))
        app.addItem(.separator())
        let settings = item(String(localized: "Réglages…"), #selector(MainMenuActions.openSettings(_:)), key: ",")
        settings.target = menuActions
        app.addItem(settings)
        app.addItem(.separator())
        app.addItem(item(String(localized: "Masquer NOYA Face"), #selector(NSApplication.hide(_:)), key: "h"))
        app.addItem(.separator())
        app.addItem(item(String(localized: "Quitter NOYA Face"), #selector(NSApplication.terminate(_:)), key: "q"))
        main.addItem(submenu(app))

        let file = NSMenu(title: String(localized: "Fichier"))
        file.addItem(item(String(localized: "Fermer la fenêtre"), #selector(NSWindow.performClose(_:)), key: "w"))
        main.addItem(submenu(file))

        let edit = NSMenu(title: String(localized: "Édition"))
        edit.addItem(item(String(localized: "Annuler"), Selector(("undo:")), key: "z")) // noloc
        edit.addItem(item(String(localized: "Rétablir"), Selector(("redo:")), key: "Z")) // noloc
        edit.addItem(.separator())
        edit.addItem(item(String(localized: "Couper"), #selector(NSText.cut(_:)), key: "x"))
        edit.addItem(item(String(localized: "Copier"), #selector(NSText.copy(_:)), key: "c"))
        edit.addItem(item(String(localized: "Coller"), #selector(NSText.paste(_:)), key: "v"))
        edit.addItem(item(String(localized: "Tout sélectionner"), #selector(NSText.selectAll(_:)), key: "a"))
        main.addItem(submenu(edit))

        let window = NSMenu(title: String(localized: "Fenêtre"))
        window.addItem(item(String(localized: "Placer dans le Dock"), #selector(NSWindow.performMiniaturize(_:)), key: "m"))
        main.addItem(submenu(window))
        NSApp.windowsMenu = window

        return main
    }

    private static func item(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: key)
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}

/// Cible des commandes de menu propres à NOYA Face.
@MainActor
final class MainMenuActions: NSObject {
    @objc func openSettings(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }
}
