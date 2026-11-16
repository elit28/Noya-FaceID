import SwiftUI

/// Diagnostic : état réel des composants et des autorisations.
struct DiagnosticPage: View {
    @State private var status = ComponentStatus()
    @State private var permissions = PermissionsModel()
    @State private var unlock = ScreenUnlockController.shared

    var body: some View {
        Form {
            Section("Composants") {
                LabeledContent("Détection de présence réelle") {
                    modelText(status.livenessModel)
                }
                LabeledContent("Reconnaissance faciale") {
                    modelText(status.recognitionModel)
                }
                LabeledContent("Encoche") {
                    Text(notchLabel)
                }
            }

            Section("Autorisations") {
                LabeledContent("Caméra") { Text(cameraLabel) }
                LabeledContent("Accessibilité") {
                    Text(accessibilityLabel)
                }
            }

            Section("Fonctions") {
                LabeledContent("Protection des applications") {
                    Text(appLockLabel)
                }
                LabeledContent("Verrouillage en cas d’absence") {
                    Text(awayLockLabel)
                }
                LabeledContent("Déverrouillage de l’écran") {
                    Text(unlockLabel)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            permissions.refresh()
            await status.refresh()
            await unlock.refresh()
        }
    }

    private var notchLabel: LocalizedStringKey {
        status.hasNotch ? "Détectée" : "Aucune (pastille)"
    }

    private var accessibilityLabel: LocalizedStringKey {
        permissions.accessibilityGranted ? "Accordée" : "Non accordée"
    }

    private var appLockLabel: LocalizedStringKey {
        AppLockController.shared.isRunning ? "Active" : "Inactive"
    }

    private var awayLockLabel: LocalizedStringKey {
        AwayLockController.shared.isEnabled ? "Activé" : "Désactivé"
    }

    private var unlockLabel: LocalizedStringKey {
        guard unlock.isEnabled else { return "Désactivé" }
        if !unlock.hasPassword { return "Mot de passe manquant" }
        return unlock.armedUntil == nil ? "Activé · désarmé" : "Activé · armé"
    }

    private var cameraLabel: LocalizedStringKey {
        switch status.cameraAuthorization {
        case .authorized: return "Autorisée"
        case .denied: return "Refusée"
        case .restricted: return "Restreinte"
        case .notDetermined: return "Pas encore demandée"
        @unknown default: return "Inconnue"
        }
    }

    private func modelText(_ state: ComponentStatus.ModelState) -> Text {
        switch state {
        case .checking: return Text("Vérification…")
        case .loaded: return Text("Modèle chargé")
        case .missing: return Text("Modèle introuvable")
        }
    }
}
