import CoreGraphics
import Foundation

public enum VerificationPipelineError: Error, Equatable {
    case noImagesProvided
    case notLive(confidence: Float)
    case corruptEnrollment
    /// Le profil a été créé avec un autre modèle ou un autre format : réenregistrement requis.
    case staleEnrollment
    /// Plus d'un visage significatif est visible : la reconnaissance est refusée.
    case multipleFaces
    /// Le visage est trop petit (trop loin) pour une reconnaissance fiable.
    case faceTooFar
    /// L'apparence à ajouter ne correspond pas au visage déjà enregistré.
    case differentPerson
}

public struct PipelineConfig: Sendable {
    /// Similarité cosinus minimale entre l'empreinte SFace d'une image et le visage enrôlé.
    /// Valeur **provisoire** : OpenCV publie 0,363 comme seuil de même identité pour SFace
    /// (mesuré sur LFW) ; NOYA Face part plus haut par prudence. Le seuil définitif sera fixé
    /// par mesure sur Mac (docs/tests/PROTOCOLE-RECONNAISSANCE.md).
    public let matchThreshold: Float
    /// Probabilité minimale de la classe « visage réel » du classifieur anti-usurpation, en
    /// plus du fait qu'elle soit la plus probable.
    public let livenessThreshold: Float
    /// Largeur minimale du visage principal, en fraction de la largeur de l'image.
    public let minimumFaceWidthFraction: CGFloat
    /// Refuser la reconnaissance si un autre visage significatif est visible.
    public let rejectMultipleFaces: Bool
    /// Un autre visage est « significatif » si sa largeur atteint cette fraction de celle
    /// du visage principal.
    public let secondFaceMinimumRatio: CGFloat

    public init(
        matchThreshold: Float = 0.42, livenessThreshold: Float = 0.6,
        minimumFaceWidthFraction: CGFloat = 0.15, rejectMultipleFaces: Bool = true, secondFaceMinimumRatio: CGFloat = 0.5
    ) {
        self.matchThreshold = matchThreshold
        self.livenessThreshold = livenessThreshold
        self.minimumFaceWidthFraction = minimumFaceWidthFraction
        self.rejectMultipleFaces = rejectMultipleFaces
        self.secondFaceMinimumRatio = secondFaceMinimumRatio
    }
}

public struct FrameEvaluation: Equatable, Sendable {
    public let liveness: Float
    public let similarity: Float
    public let isLive: Bool
    public let isMatch: Bool

    public var accepted: Bool { isLive && isMatch }
}

/// Détection → présence réelle → empreinte → comparaison avec le visage enregistré.
public final class VerificationPipeline {
    private let detector: FaceDetecting
    private let embedder: FaceEmbedding_Provider
    private let classifier: LivenessChecking
    private let store: SecureStore
    private let modelIdentifier: String
    public let config: PipelineConfig
    static let profileKey = "face-profile"
    /// Nom donné à l'apparence créée par le premier enrôlement (traduit par l'app à l'affichage).
    public static let defaultAppearanceName = "Standard"

    public init(
        detector: FaceDetecting = VisionFaceDetector(), embedder: FaceEmbedding_Provider, classifier: LivenessChecking,
        store: SecureStore, config: PipelineConfig = PipelineConfig(), modelIdentifier: String = FaceEmbedder.modelIdentifier
    ) {
        self.detector = detector
        self.embedder = embedder
        self.classifier = classifier
        self.store = store
        self.config = config
        self.modelIdentifier = modelIdentifier
    }

    /// Un échantillon d'enrôlement : l'image doit contenir un seul visage, assez proche,
    /// qui passe la détection de présence réelle (une photo ne peut pas être enrôlée).
    public func enrollmentSample(from image: CGImage) throws -> (embedding: FaceEmbedding, liveness: LivenessResult) {
        let (face, frame) = try detect(in: image)
        let liveness = try classifier.liveness(for: face, in: frame)
        guard isLive(liveness) else { throw VerificationPipelineError.notLive(confidence: liveness.confidence) }
        return (try embedder.embedding(for: face, in: frame), liveness)
    }

    /// Échantillon d'enrôlement guidé : comme `enrollmentSample`, avec l'orientation de la tête.
    public func guidedSample(from image: CGImage) throws -> GuidedSample {
        let (face, frame) = try detect(in: image)
        let liveness = try classifier.liveness(for: face, in: frame)
        guard isLive(liveness) else { throw VerificationPipelineError.notLive(confidence: liveness.confidence) }
        return GuidedSample(
            embedding: try embedder.embedding(for: face, in: frame), liveness: liveness,
            pose: FacePose.estimate(from: face.landmarks)
        )
    }

    // MARK: - Profil

    /// Premier enrôlement (ou réenregistrement complet) : remplace le profil par une seule
    /// apparence « Standard ». Retourne la moyenne enregistrée.
    @discardableResult
    public func saveEnrollment(_ embeddings: [FaceEmbedding]) throws -> FaceEmbedding {
        let appearance = try FaceAppearance.make(name: Self.defaultAppearanceName, from: embeddings)
        try saveProfile(FaceProfile(model: modelIdentifier, appearances: [appearance]))
        return FaceEmbedding(vector: appearance.centroid)
    }

    /// Ajoute une apparence (lunettes, barbe…) au visage déjà enregistré. Refusée si elle
    /// ne correspond pas à ce visage : impossible d'enregistrer une autre personne.
    @discardableResult
    public func addAppearance(named name: String, from embeddings: [FaceEmbedding]) throws -> FaceAppearance {
        var profile = try loadProfile()
        let appearance = try FaceAppearance.make(name: name, from: embeddings)
        guard let match = profile.bestMatch(for: FaceEmbedding(vector: appearance.centroid)),
              match.centroidSimilarity >= config.matchThreshold else {
            throw VerificationPipelineError.differentPerson
        }
        profile.appearances.append(appearance)
        try saveProfile(profile)
        return appearance
    }

    public func enroll(images: [CGImage]) throws {
        guard !images.isEmpty else { throw VerificationPipelineError.noImagesProvided }
        try saveEnrollment(images.map { try enrollmentSample(from: $0).embedding })
    }

    public func loadProfile() throws -> FaceProfile {
        let data = try store.load(Self.profileKey)
        guard let profile = try? JSONDecoder().decode(FaceProfile.self, from: data) else {
            throw VerificationPipelineError.corruptEnrollment
        }
        guard profile.formatVersion == FaceProfile.currentFormatVersion, profile.model == modelIdentifier else {
            throw VerificationPipelineError.staleEnrollment
        }
        return profile
    }

    public func saveProfile(_ profile: FaceProfile) throws {
        try store.save(JSONEncoder().encode(profile), as: Self.profileKey)
    }

    // MARK: - Vérification

    public func evaluate(image: CGImage, against profile: FaceProfile) throws -> FrameEvaluation {
        let (face, frame) = try detect(in: image)
        let liveness = try classifier.liveness(for: face, in: frame)
        let candidate = try embedder.embedding(for: face, in: frame)
        // Dimension différente (fichier corrompu, autre modèle) : aucune apparence ne
        // correspond, le refus est sûr.
        let match = profile.bestMatch(for: candidate)
        return FrameEvaluation(
            liveness: liveness.confidence, similarity: match?.centroidSimilarity ?? -1,
            isLive: isLive(liveness), isMatch: match?.passes(threshold: config.matchThreshold) ?? false
        )
    }

    public func verify(image: CGImage) throws -> Bool {
        try evaluate(image: image, against: loadProfile()).accepted
    }

    private func isLive(_ result: LivenessResult) -> Bool {
        result.isLive && result.confidence >= config.livenessThreshold
    }

    private func detect(in image: CGImage) throws -> (DetectedFace, RGBAImage) {
        let detection = try detector.detectFaces(in: image)
        let face = detection.primary
        if image.width > 0, face.boundingBox.width / CGFloat(image.width) < config.minimumFaceWidthFraction {
            throw VerificationPipelineError.faceTooFar
        }
        if config.rejectMultipleFaces,
           detection.otherFaceWidths.contains(where: { $0 >= face.boundingBox.width * config.secondFaceMinimumRatio }) {
            throw VerificationPipelineError.multipleFaces
        }
        guard let frame = RGBAImage(cgImage: image) else { throw FaceEmbedderError.inferenceFailed }
        return (face, frame)
    }
}
