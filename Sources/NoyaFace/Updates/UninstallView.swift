import AppKit
import NoyaCore
import NoyaEngine
import ServiceManagement
import SwiftUI

/// Désinstallation complète (maquette Uninstall validée) : visage, mot de passe et clé du
/// trousseau, réglages et journaux, ouverture à la connexion, autorisations si macOS le
/// permet, puis l'app elle-même à la Corbeille.
struct UninstallView: View {
    let onCancel: () -> Void

    enum Phase {
        case confirm
        case running
        case done
        case cancelled
    }

    enum Item: Int, CaseIterable {
        case face, password, settings, loginItem, permissions, app

        var label: LocalizedStringKey {
            switch self {
            case .face: return "Votre visage (empreintes chiffrées)"
            case .password: return "Mot de passe enregistré et clé du trousseau"
            case .settings: return "Réglages et journaux"
            case .loginItem: return "Ouverture à la connexion"
            case .permissions: return "Autorisations macOS (si possible)"
            case .app: return "L’application NOYA Face"
            }
        }
    }

    @State private var phase: Phase = .confirm
    @State private var removed: Set<Item> = []
    @State private var permissionsReset = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.weight(.bold))
            Text(lead)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Item.allCases, id: \.self) { item in
                    HStack(spacing: 10) {
                        Image(systemName: removed.contains(item) ? "checkmark.circle.fill" : "circle") // noloc
                            .foregroundStyle(removed.contains(item) ? Color.green : Color.secondary)
                            .accessibilityHidden(true)
                        Text(item.label)
                        Spacer()
                        Text(state(of: item))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            if !permissionsReset {
                Text("macOS n’a pas permis de retirer les autorisations : retirez NOYA Face dans Réglages Système › Confidentialité et sécurité › Caméra et Accessibilité.")
                    .font(.callout)
                    .foregroundStyle(.orange)
            } else {
                Text("Les autorisations accordées dans Réglages Système sont retirées si macOS le permet ; sinon, NOYA Face vous indique où le faire.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                switch phase {
                case .confirm, .cancelled:
                    Button("Annuler", action: onCancel)
                        .keyboardShortcut(.cancelAction)
                    Button("Désinstaller", role: .destructive) { Task { await uninstall() } }
                        .keyboardShortcut(.defaultAction)
                case .running:
                    ProgressView().controlSize(.small)
                case .done:
                    Button("Placer dans la Corbeille et quitter") { trashAndQuit() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private var title: LocalizedStringKey {
        switch phase {
        case .confirm, .cancelled: return "Désinstaller NOYA Face ?"
        case .running: return "Suppression en cours…"
        case .done: return "Données supprimées"
        }
    }

    private var lead: LocalizedStringKey {
        switch phase {
        case .confirm: return "Tout ce qui suit sera supprimé de ce Mac. Confirmation par Touch ID ou votre mot de passe macOS."
        case .cancelled: return "Authentification annulée : rien n’a été supprimé."
        case .running: return "Ne fermez pas cette fenêtre."
        case .done: return "Il reste à placer l’application dans la Corbeille. NOYA Face se fermera ensuite."
        }
    }

    private func state(of item: Item) -> LocalizedStringKey {
        if removed.contains(item) { return "Supprimé" }
        if phase == .done && item == .app { return "À la Corbeille" }
        return ""
    }

    private func uninstall() async {
        let reason = String(localized: "désinstaller NOYA Face et supprimer vos données")
        guard await LocalSystemAuth().authenticate(reason: reason) == .success else {
            phase = .cancelled
            return
        }
        phase = .running

        // Plus aucune protection active : quitter ne demandera plus d'authentification.
        AppLockController.shared.store.enabled = false
        AppLockController.shared.refresh()
        UserDefaults.standard.set(false, forKey: FeatureKeys.awayLock)
        AwayLockController.shared.refresh()
        await ScreenUnlockController.shared.disable()

        if let runtime = await AppModel.shared.loadRuntime() {
            try? runtime.removeAllData()
        }
        try? KeychainKeyProvider(account: NSUserName(), interactive: true).deleteKey()
        try? FileManager.default.removeItem(at: NoyaRuntime.defaultSupportDirectory)
        removed.insert(.face)
        removed.insert(.password)

        try? FileManager.default.removeItem(at: AppLog.shared.url)
        try? FileManager.default.removeItem(at: AppLog.shared.rotatedURL)
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        removed.insert(.settings)

        try? await SMAppService.mainApp.unregister()
        removed.insert(.loginItem)

        permissionsReset = await Self.resetPermissions()
        if permissionsReset { removed.insert(.permissions) }

        phase = .done
    }

    /// `tccutil` est l'outil d'Apple pour remettre à zéro les autorisations d'une app.
    private static func resetPermissions() async -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil") // noloc
            process.arguments = ["reset", "All", bundleID] // noloc
            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }

    private func trashAndQuit() {
        NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, _ in
            Task { @MainActor in NSApplication.shared.terminate(nil) }
        }
    }
}
