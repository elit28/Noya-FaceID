import Foundation
import NoyaCore

/// Appréciation d'une note de qualité.
public enum ScanGrade: Equatable, Sendable {
    case excellent
    case good
    case fair
    case poor
}

/// Note de qualité d'un scan, de 0 à 100, calculée uniquement à partir de valeurs mesurées :
/// la marge entre la ressemblance des empreintes et le seuil de reconnaissance, et le score
/// de présence réelle. C'est un indicateur de confort (le visage sera-t-il bien reconnu ?),
/// pas une mesure de sécurité.
public enum ScanQuality {
    /// Marge au-dessus du seuil de correspondance qui donne la note maximale.
    public static let fullMargin: Float = 0.30
    /// Score de présence réelle qui donne la note maximale.
    public static let fullLiveness: Float = 0.95

    /// Cohérence d'un enregistrement : ressemblance moyenne des empreintes à leur moyenne.
    public static func consistency(of embeddings: [FaceEmbedding]) -> Float? {
        guard !embeddings.isEmpty else { return nil }
        let normalized = embeddings.map(EmbeddingMath.normalized)
        let center = EmbeddingMath.normalized(EmbeddingMath.centroid(of: normalized))
        let total = normalized.reduce(Float(0)) { $0 + EmbeddingMath.cosineSimilarity($1, center) }
        return total / Float(normalized.count)
    }

    public static func consistency(of appearance: FaceAppearance) -> Float? {
        consistency(of: appearance.samples.map { FaceEmbedding(vector: $0) })
    }

    /// Note d'un enregistrement : marge de cohérence au-dessus du seuil.
    public static func enrollmentScore(consistency: Float, threshold: Float) -> Int {
        percent(margin(consistency, above: threshold))
    }

    /// Note d'une vérification : trois quarts pour la marge de correspondance, un quart pour
    /// la présence réelle.
    public static func verificationScore(similarity: Float, threshold: Float,
                                         liveness: Float, livenessThreshold: Float) -> Int {
        let match = margin(similarity, above: threshold)
        let live = clamp((liveness - livenessThreshold) / max(fullLiveness - livenessThreshold, 0.01))
        return percent(0.75 * match + 0.25 * live)
    }

    public static func grade(_ score: Int) -> ScanGrade {
        if score >= 80 { return .excellent }
        if score >= 60 { return .good }
        if score >= 40 { return .fair }
        return .poor
    }

    private static func margin(_ value: Float, above threshold: Float) -> Float {
        clamp((value - threshold) / fullMargin)
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private static func percent(_ value: Float) -> Int {
        Int((value * 100).rounded())
    }
}
