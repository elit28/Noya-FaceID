import AppKit
import NoyaEngine
import SwiftUI

/// Paramètres avancés : démarrage, journal, assistant.
struct AdvancedPage: View {
    @State private var permissions = PermissionsModel()

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

            Section("Configuration") {
                Button("Relancer l’assistant de configuration") {
                    OnboardingWindowController.shared.show()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { permissions.refresh() }
    }
}
