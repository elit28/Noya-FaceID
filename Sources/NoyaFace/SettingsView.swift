import AVFoundation
import SwiftUI

/// Réglages du socle (jalon J1). Uniquement des fonctions réelles : visibilité de l'icône,
/// langue, état des composants et confidentialité. Les écrans complets validés en maquette
/// arrivent avec les jalons suivants.
struct SettingsView: View {
    @AppStorage(PreferenceKeys.menuBarIconVisible) private var menuBarIconVisible = true
    @State private var status = ComponentStatus()

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: BrandMark.appIconImage(size: 56))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: AppInfo.name)
                            .font(.title2.weight(.bold))
                        HStack(spacing: 4) {
                            Text("Version de développement")
                            Text(verbatim: AppInfo.version)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                Text("Version de développement : d’autres fonctions arrivent dans les prochains jalons.")
                    .foregroundStyle(.secondary)
            }

            ProtectedAppsSection()

            AwayLockSection()

            Section("Barre des menus") {
                Toggle("Afficher l’icône dans la barre des menus", isOn: $menuBarIconVisible)
                if !menuBarIconVisible {
                    Text("Icône masquée : relancez NOYA Face depuis le dossier Applications ou Spotlight pour rouvrir cette fenêtre.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Langue") {
                Text("NOYA Face suit la langue de macOS. Pour choisir une langue propre à cette app : Réglages Système › Général › Langue et région › Applications.")
                    .foregroundStyle(.secondary)
            }

            Section("État des composants") {
                LabeledContent("Caméra") {
                    Text(cameraLabel)
                }
                LabeledContent("Détection de présence réelle") {
                    modelText(status.livenessModel, missing: "Modèle introuvable")
                }
                LabeledContent("Reconnaissance faciale") {
                    modelText(status.recognitionModel, missing: "Modèle introuvable")
                }
                LabeledContent("Encoche") {
                    Text(notchLabel)
                }
            }

            Section("Confidentialité") {
                Text("Traitement entièrement local. Aucune image n’est enregistrée, aucune donnée n’est envoyée.")
                Text("Composants tiers : HeyMac (MIT), Silent-Face-Anti-Spoofing (Apache-2.0), SFace d’OpenCV Zoo (Apache-2.0). Détails dans THIRD_PARTY_NOTICES.md.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 560)
        .task {
            await status.refresh()
        }
    }

    private var cameraLabel: LocalizedStringKey {
        switch status.cameraAuthorization {
        case .authorized:
            return "Autorisée"
        case .denied:
            return "Refusée"
        case .restricted:
            return "Restreinte"
        case .notDetermined:
            return "Pas encore demandée"
        @unknown default:
            return "Inconnue"
        }
    }

    private var notchLabel: LocalizedStringKey {
        if status.hasNotch {
            return "Détectée"
        }
        return "Aucune (pastille)"
    }

    private func modelText(_ state: ComponentStatus.ModelState, missing: LocalizedStringKey) -> Text {
        switch state {
        case .checking:
            return Text("Vérification…")
        case .loaded:
            return Text("Modèle chargé")
        case .missing:
            return Text(missing)
        }
    }
}
