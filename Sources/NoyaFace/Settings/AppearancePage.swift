import SwiftUI

/// Apparence : île de l'encoche, barre des menus et langue.
struct AppearancePage: View {
    @AppStorage(IslandKeys.enabled) private var islandEnabled = true
    @AppStorage(IslandKeys.style) private var islandStyle: IslandStyle = .sides
    @AppStorage(PreferenceKeys.menuBarIconVisible) private var menuBarIconVisible = true
    @State private var hasNotch = NSScreen.screens.contains { $0.safeAreaInsets.top > 0 }

    var body: some View {
        Form {
            Section("Île de l’encoche") {
                Toggle(isOn: $islandEnabled) {
                    Text("Afficher l’île autour de l’encoche")
                    Text(islandHint)
                }
                if islandEnabled {
                    Picker("Style", selection: $islandStyle) {
                        Text("Côtés").tag(IslandStyle.sides)
                        Text("Discret").tag(IslandStyle.discreet)
                    }
                    .pickerStyle(.segmented)
                    LabeledContent {
                        HStack {
                            Button("Recherche") { IslandController.shared.flash(.searching, seconds: 2) }
                            Button("Reconnu") { IslandController.shared.flash(.success) }
                            Button("Non reconnu") { IslandController.shared.flash(.refused, seconds: 1.6) }
                        }
                    } label: {
                        Text("Essayer")
                        Text("Affiche un exemple à l’écran.")
                    }
                    Text("L’île n’apparaît pas sur l’écran verrouillé : il faudrait des API privées de macOS.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

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
        }
        .formStyle(.grouped)
    }

    private var islandHint: LocalizedStringKey {
        hasNotch
            ? "Les informations s’affichent de chaque côté de l’encoche."
            : "Ce Mac n’a pas d’encoche : une pastille s’affiche en haut au centre."
    }
}
