import NoyaEngine
import SwiftUI

/// Sécurité : détection du visage, exigence de correspondance, verrouillage automatique et
/// déverrouillage de l'écran.
struct SecurityPage: View {
    @State private var scanSeconds = AppModel.shared.settings.scanSeconds
    @State private var distance = AppModel.shared.settings.detectionDistance
    @State private var strictness = AppModel.shared.settings.strictness

    private static let scanChoices = [2, 3, 5, 7, 10]

    var body: some View {
        Form {
            Section("Détection") {
                Picker(selection: $scanSeconds) {
                    ForEach(Self.scanChoices, id: \.self) { seconds in
                        Text("\(seconds) s").tag(seconds)
                    }
                } label: {
                    Text("Durée de recherche du visage")
                    Text("Au-delà, la caméra s’éteint et Touch ID ou le mot de passe est proposé.")
                }
                .onChange(of: scanSeconds) { AppModel.shared.settings.scanSeconds = scanSeconds }

                Picker(selection: $distance) {
                    ForEach(DetectionDistance.allCases, id: \.self) { value in
                        Text(label(for: value)).tag(value)
                    }
                } label: {
                    Text("Distance de détection")
                    Text("Éloignée : pratique, mais moins précise.")
                }
                .onChange(of: distance) { AppModel.shared.settings.detectionDistance = distance }
            }

            Section("Reconnaissance") {
                Picker(selection: $strictness) {
                    ForEach(MatchStrictness.allCases, id: \.self) { value in
                        Text(label(for: value)).tag(value)
                    }
                } label: {
                    Text("Exigence de correspondance")
                    Text("Stricte : moins de risque d’accepter une autre personne, mais plus de refus pour vous.")
                }
                .onChange(of: strictness) { AppModel.shared.settings.strictness = strictness }
                LabeledContent {
                    Text("Toujours")
                } label: {
                    Text("Refuser si plusieurs visages sont visibles")
                    Text("Pour les applications protégées et l’écran verrouillé.")
                }
                LabeledContent {
                    Text("Stricte")
                } label: {
                    Text("Détection de présence réelle")
                    Text("Analyse de texture contre les photos et les écrans. Ne bloque pas toutes les vidéos.")
                }
            }

            AwayLockSection()

            ScreenUnlockSection()
        }
        .formStyle(.grouped)
    }

    private func label(for distance: DetectionDistance) -> LocalizedStringKey {
        switch distance {
        case .close: return "Proche"
        case .standard: return "Standard"
        case .far: return "Éloignée"
        }
    }

    private func label(for strictness: MatchStrictness) -> LocalizedStringKey {
        switch strictness {
        case .relaxed: return "Souple"
        case .normal: return "Standard"
        case .strict: return "Stricte"
        }
    }
}
