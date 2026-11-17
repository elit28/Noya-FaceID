import NoyaEngine
import SwiftUI

/// Note de qualité d'un scan (0 à 100) et son appréciation, avec le détail des mesures.
struct ScanQualityView: View {
    let score: Int
    /// Ressemblance moyenne des empreintes à leur moyenne, et seuil de reconnaissance.
    let consistency: Float
    let threshold: Float
    /// Proposé seulement quand la note est faible.
    var onRetry: (() -> Void)?

    var body: some View {
        let measured = Self.format(consistency)
        let required = Self.format(threshold)
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("Qualité du scan : \(score)/100")
                    .font(.headline)
                StatusBadge(text: ScanQualityText.grade(score), positive: score >= 60)
            }
            Text("Cohérence de vos empreintes : \(measured) (seuil \(required))")
                .font(.callout)
                .foregroundStyle(.secondary)
                .help(Text("La note mesure la ressemblance de vos empreintes entre elles, comparée au seuil de reconnaissance : un indicateur de confort, pas de sécurité."))
            if score < 60 {
                Text("Pour une meilleure note : bonne lumière de face, pas de contre-jour, visage entier dans le cercle.")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                if let onRetry {
                    Button("Refaire le scan", action: onRetry)
                }
            }
        }
    }

    static func format(_ value: Float) -> String {
        Double(value).formatted(.number.precision(.fractionLength(2)))
    }
}

enum ScanQualityText {
    static func grade(_ score: Int) -> LocalizedStringKey {
        switch ScanQuality.grade(score) {
        case .excellent: return "Excellente"
        case .good: return "Bonne"
        case .fair: return "Moyenne"
        case .poor: return "Faible"
        }
    }
}
