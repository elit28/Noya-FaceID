import AppKit
import NoyaEngine
import SwiftUI

/// Paramètres avancés : démarrage, journal, assistant.
struct AdvancedPage: View {
    @State private var permissions = PermissionsModel()
    @State private var updates = UpdateChecker.shared
    @State private var uninstalling = false
    @AppStorage(UpdateKeys.automatic) private var automaticUpdates = false

    var body: some View {
        Form {
            Section("Démarrage") {
                Toggle(isOn: Binding(get: { permissions.openAtLogin }, set: { isOn in permissions.setOpenAtLogin(isOn) })) {
                    Text("Ouvrir à l’ouverture de session")
                    Text("Pour que la protection soit active dès la connexion.")
                }
                if permissions.loginItemNeedsApproval {
                    Text("À approuver dans Réglages Système › Général › Ouverture.")
                        .foregroundStyle(.orange)
                }
            }

            Section("Journal") {
                LabeledContent {
                    Button("Afficher dans le Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([AppLog.shared.url])
                    }
                } label: {
                    Text("Journal de diagnostic")
                    Text("Scores et erreurs uniquement : jamais d’image, d’empreinte ni de mot de passe.")
                }
            }

            Section("Mises à jour") {
                Toggle(isOn: $automaticUpdates) {
                    Text("Rechercher les mises à jour automatiquement")
                    Text("Une fois par jour, NOYA Face interroge GitHub pour connaître la dernière version. Aucune autre donnée n’est envoyée. Désactivé par défaut.")
                }
                LabeledContent {
                    HStack {
                        if case .available = updates.state {
                            Button("Télécharger") { updates.openDownloadPage() }
                                .buttonStyle(.borderedProminent)
                        }
                        Button("Rechercher maintenant") { Task { await updates.check() } }
                            .disabled(updates.state == .checking)
                    }
                } label: {
                    Text("Version installée : \(AppInfo.version)")
                    Text(updateStatus)
                }
            }

            Section("Configuration") {
                Button("Relancer l’assistant de configuration") {
                    OnboardingWindowController.shared.show()
                }
            }

            Section("Désinstallation") {
                LabeledContent {
                    Button("Désinstaller…", role: .destructive) { uninstalling = true }
                } label: {
                    Text("Désinstaller NOYA Face")
                    Text("Supprime votre visage, le mot de passe enregistré, la clé du trousseau, les réglages et l’app.")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { permissions.refresh() }
        .sheet(isPresented: $uninstalling) {
            UninstallView(onCancel: { uninstalling = false })
        }
    }

    private var updateStatus: LocalizedStringKey {
        switch updates.state {
        case .idle: return "Pas encore recherchée."
        case .checking: return "Recherche…"
        case .upToDate: return "NOYA Face est à jour."
        case .available(let version, _): return "La version \(version) est disponible."
        case .failed: return "Recherche impossible (pas de connexion ?)."
        }
    }
}
