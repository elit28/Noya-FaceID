import NoyaEngine
import SwiftUI

/// Réglages « Applications protégées » (maquette Main validée, page Applications).
struct ProtectedAppsSection: View {
    @AppStorage(FeatureKeys.appProtection) private var enabled = false
    @AppStorage(AppLockKeys.mask) private var mask: ShieldMask = .opaque
    @AppStorage(AppLockKeys.relockOnSleep) private var relockOnSleep = true
    @State private var apps: [LockedApp] = AppLockController.shared.store.apps
    @State private var showingPicker = false

    private var store: LockedAppStore { AppLockController.shared.store }

    var body: some View {
        Section {
            Toggle("Protéger des applications", isOn: $enabled)
                .onChange(of: enabled) { AppLockController.shared.refresh() }
            Text("Une application protégée est masquée jusqu’à votre authentification : visage, puis Touch ID ou mot de passe macOS.")
                .foregroundStyle(.secondary)
            WarningNote(text: "Protection de confidentialité, pas un coffre-fort : elle empêche un regard indiscret ou un accès opportuniste. L’application continue de fonctionner en arrière-plan et ses données restent lisibles sur le disque par d’autres moyens.")
        } header: {
            Text("Applications protégées")
        }

        Section("Règles générales") {
            Picker(selection: $mask) {
                Text("Opaque").tag(ShieldMask.opaque)
                Text("Flou").tag(ShieldMask.blur)
            } label: {
                Text("Masque")
                Text("Opaque : rien n’est visible. Flou : la mise en page reste devinable.")
            }
            LabeledContent {
                Text("Système")
            } label: {
                Text("Méthode de secours")
                Text("Touch ID si disponible, sinon mot de passe macOS. Vérifiés par macOS, jamais stockés par NOYA Face.")
            }
            Toggle("Reverrouiller à la mise en veille et au verrouillage du Mac", isOn: $relockOnSleep)
        }

        Section("Applications") {
            if apps.isEmpty {
                Text("Aucune application protégée pour l’instant.")
                    .foregroundStyle(.secondary)
            }
            ForEach(apps) { app in
                HStack(spacing: 10) {
                    AppIconView(bundleID: app.bundleID, path: nil, size: 22)
                    Picker(selection: policyBinding(for: app)) {
                        ForEach(policyChoices(for: app.policy), id: \.self) { policy in
                            Text(label(for: policy)).tag(policy)
                        }
                    } label: {
                        Text(app.name)
                    }
                    Button {
                        store.remove(bundleID: app.bundleID)
                        reload()
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help(Text("Ne plus protéger \(app.name)"))
                    .accessibilityLabel(Text("Ne plus protéger \(app.name)"))
                }
            }
            Button("Choisir les applications…") { showingPicker = true }
            Text("Toujours accessibles, pour pouvoir corriger une erreur : Terminal, Réglages Système, Moniteur d’activité, Finder et NOYA Face.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showingPicker) {
            AppPickerView(current: apps, onCancel: { showingPicker = false }, onConfirm: apply)
        }
    }

    private func apply(_ selected: [PickerApp]) {
        let selectedIDs = Set(selected.map(\.bundleID))
        for app in apps where !selectedIDs.contains(app.bundleID) {
            store.remove(bundleID: app.bundleID)
        }
        for app in selected where store.app(app.bundleID) == nil {
            store.add(bundleID: app.bundleID, name: app.name, policy: .afterFocusLossMinutes(5))
        }
        showingPicker = false
        reload()
    }

    private func reload() {
        apps = store.apps
        AppLockController.shared.refresh()
    }

    private func policyBinding(for app: LockedApp) -> Binding<RelockPolicy> {
        Binding(
            get: { store.app(app.bundleID)?.policy ?? app.policy },
            set: { policy in
                store.setPolicy(policy, for: app.bundleID)
                apps = store.apps
            }
        )
    }

    private static let standardPolicies: [RelockPolicy] = [
        .everyTime, .afterFocusLossMinutes(5), .afterFocusLossMinutes(15), .untilQuit,
    ]

    private func policyChoices(for current: RelockPolicy) -> [RelockPolicy] {
        Self.standardPolicies.contains(current) ? Self.standardPolicies : Self.standardPolicies + [current]
    }

    private func label(for policy: RelockPolicy) -> LocalizedStringKey {
        switch policy {
        case .everyTime: return "À chaque ouverture"
        case .afterFocusLossMinutes(let minutes): return "Après \(minutes) min d’inactivité"
        case .afterMinutes(let minutes): return "\(minutes) min après le déverrouillage"
        case .untilQuit: return "Quand je quitte l’app"
        }
    }
}
