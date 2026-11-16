import Foundation

/// Une apparence du visage enregistré : « Standard », « Avec lunettes »… Toutes les
/// apparences appartiennent à la **même personne** : NOYA Face n'enregistre qu'un visage
/// par Mac (décision du projet). Aucune image n'est conservée, seulement des empreintes.
public struct FaceAppearance: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var isEnabled: Bool
    /// Moyenne normalisée des empreintes de l'apparence.
    public var centroid: [Float]
    /// Empreintes individuelles (normalisées), utilisées pour exiger qu'un échantillon
    /// précis ressemble aussi au visage présenté, pas seulement la moyenne.
    public var samples: [[Float]]

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date(), isEnabled: Bool = true,
                centroid: [Float], samples: [[Float]]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isEnabled = isEnabled
        self.centroid = centroid
        self.samples = samples
    }

    /// Construit une apparence à partir des empreintes d'un enrôlement.
    public static func make(name: String, from embeddings: [FaceEmbedding], createdAt: Date = Date()) throws -> FaceAppearance {
        guard !embeddings.isEmpty else { throw VerificationPipelineError.noImagesProvided }
        let normalized = embeddings.map(EmbeddingMath.normalized)
        let dimension = normalized[0].vector.count
        guard dimension > 0, normalized.allSatisfy({ $0.vector.count == dimension }) else {
            throw VerificationPipelineError.corruptEnrollment
        }
        let centroid = EmbeddingMath.normalized(EmbeddingMath.centroid(of: normalized))
        return FaceAppearance(name: name, createdAt: createdAt, centroid: centroid.vector, samples: normalized.map(\.vector))
    }
}

/// Résultat de la comparaison d'une empreinte avec la meilleure apparence active.
public struct ProfileMatch: Equatable, Sendable {
    public let appearanceID: UUID
    public let centroidSimilarity: Float
    public let bestSampleSimilarity: Float

    /// Correspondance retenue seulement si la moyenne **et** le meilleur échantillon
    /// dépassent le seuil (une moyenne trop « floue » ne suffit pas).
    public func passes(threshold: Float) -> Bool {
        centroidSimilarity >= threshold && bestSampleSimilarity >= threshold
    }
}

/// Le visage enregistré sur ce Mac, avec ses apparences. Chiffré dans le SecureStore.
public struct FaceProfile: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    /// Identifiant du modèle qui a produit les empreintes : un changement de modèle rend
    /// le profil inutilisable (réenregistrement demandé), jamais comparé à tort.
    public var model: String
    public var appearances: [FaceAppearance]

    public init(model: String, appearances: [FaceAppearance]) {
        self.formatVersion = Self.currentFormatVersion
        self.model = model
        self.appearances = appearances
    }

    public var enabledAppearances: [FaceAppearance] {
        appearances.filter(\.isEnabled)
    }

    /// Meilleure apparence active pour `embedding` (par similarité de la moyenne).
    /// `nil` si aucune apparence n'est active ou si les dimensions ne correspondent pas.
    public func bestMatch(for embedding: FaceEmbedding) -> ProfileMatch? {
        let candidate = EmbeddingMath.normalized(embedding)
        var best: ProfileMatch?
        for appearance in enabledAppearances {
            guard appearance.centroid.count == candidate.vector.count else { continue }
            let centroidSimilarity = EmbeddingMath.cosineSimilarity(FaceEmbedding(vector: appearance.centroid), candidate)
            let bestSample = appearance.samples
                .filter { $0.count == candidate.vector.count }
                .map { EmbeddingMath.cosineSimilarity(FaceEmbedding(vector: $0), candidate) }
                .max() ?? centroidSimilarity
            let match = ProfileMatch(appearanceID: appearance.id, centroidSimilarity: centroidSimilarity, bestSampleSimilarity: bestSample)
            if best == nil || match.centroidSimilarity > best!.centroidSimilarity {
                best = match
            }
        }
        return best
    }
}
