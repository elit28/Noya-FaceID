import NoyaEngine
import SwiftUI

/// Réglages « Verrouillage automatique » (maquette Main validée, page Sécurité).
struct AwayLockSection: View {
    @AppStorage(FeatureKeys.awayLock) private var enabled = false
    @AppStorage(AwayLockKeys.idleMinutes) private var idleMinutes = 2
    @State private var permissions = PermissionsModel()

    var body: some View {
        Section("Verrouillage automatique") {
            Toggle(isOn: $enabled) {
                Text("Verrouiller le Mac quand je m’éloigne")
                Text("La caméra ne s’allume qu’après une période sans clavier ni souris, puis vérifie brièvement votre présence.")
            }
            .onChange(of: enabled) { AwayLockController.shared.refresh() }
            if enabled {
                Picker("Délai d’absence", selection: $idleMinutes) {
                    ForEach(AwayLockConfig.idleDelayChoices, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                LabeledContent {
                    if permissions.accessibilityGranted {
                        StatusBadge(text: "Accordée", positive: true)
                    } else {
                        Button("Ouvrir Réglages Système") { permissions.requestAccessibility() }
                    }
                } label: {
                    Text("Accessibilité")
                    Text("Nécessaire pour envoyer le raccourci système de verrouillage (⌃⌘Q).")
                }
                Text("Le voyant vert de la caméra s’allume pendant chaque vérification. C’est voulu : aucune capture n’est faite à votre insu.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { permissions.refresh() }
    }
}
