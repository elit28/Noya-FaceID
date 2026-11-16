import CoreGraphics
import Foundation
import NoyaCore

/// Ce dont l'enrôlement guidé a besoin du pipeline de reconnaissance.
public protocol GuidedEnrollmentSampling: AnyObject {
    func guidedSample(from image: CGImage) throws -> GuidedSample
    @discardableResult
    func saveEnrollment(_ embeddings: [FaceEmbedding]) throws -> FaceEmbedding
    @discardableResult
    func addAppearance(named name: String, from embeddings: [FaceEmbedding]) throws -> FaceAppearance
}

extension VerificationPipeline: GuidedEnrollmentSampling {}

/// Réglages de l'enrôlement guidé.
public struct GuidedEnrollmentConfig: Sendable {
    /// Nombre de secteurs du cercle à remplir en tournant la tête.
    public var sectorCount = 12
    /// Écart minimal par rapport à la position de face pour compter comme « tête tournée ».
    public var minimumOffset = 0.12
    /// Le mouvement vertical du nez est plus faible que l'horizontal : il est amplifié.
    public var verticalGain = 2.0
    /// Échantillons pris de face au début de chaque tour (position de référence).
    public var centerSamples = 3
    /// Fraction du cercle à remplir : 1 par défaut, réduite par l'option d'accessibilité.
    public var requiredFraction = 1.0
    /// Durée maximale d'un tour.
    public var scanTimeout: TimeInterval = 45
    /// Intervalle minimal entre deux images analysées.
    public var sampleSpacing: TimeInterval = 0.1

    public init() {}

    /// Option d'accessibilité : mouvement de tête réduit, la moitié du cercle suffit.
    public static var partialCircle: GuidedEnrollmentConfig {
        var config = GuidedEnrollmentConfig()
        config.requiredFraction = 0.5
        config.minimumOffset = 0.08
        return config
    }
}

/// Raison pour laquelle une image n'a pas été retenue (affichée à l'utilisateur).
public enum GuidedEnrollmentIssue: Equatable, Sendable {
    case noFace
    case multipleFaces
    case tooFar
    case notLive
}

/// Événements de l'enrôlement guidé, pour l'interface (anneau de traits, consignes).
public enum GuidedEnrollmentEvent: Equatable, Sendable {
    /// Prise de la position de face.
    case calibrating(captured: Int, needed: Int)
    /// Secteurs remplis et direction actuelle de la tête (radians, vue en miroir comme dans
    /// l'aperçu : 0 = droite de l'écran, sens horaire) ; `nil` quand la tête est de face.
    case progress(filled: [Bool], direction: Double?)
    case issue(GuidedEnrollmentIssue)
}

public enum GuidedEnrollmentError: Error, Equatable {
    case cameraBusy
    case cameraUnavailable
    case cancelled
    case timedOut(filledSectors: Int, totalSectors: Int)
}

/// Enrôlement « comme sur iPhone » : l'utilisateur tourne lentement la tête et chaque secteur
/// du cercle se remplit quand la tête pointe dans cette direction avec un visage réel, seul et
/// assez proche. Deux tours complets forment l'enrôlement. Aucune image n'est conservée.
///
/// Utilisé depuis un seul fil d'exécution à la fois (marqué `@unchecked Sendable` pour pouvoir
/// être confié à une tâche d'arrière-plan).
public final class GuidedEnroller: @unchecked Sendable {
    private let frames: FrameSource
    private let sampler: GuidedEnrollmentSampling
    private let sessionLock: NSLock
    private let config: GuidedEnrollmentConfig
    private let clock: () -> Date
    private let sleep: (TimeInterval) -> Void

    public init(
        frames: FrameSource, sampler: GuidedEnrollmentSampling, sessionLock: NSLock = NSLock(),
        config: GuidedEnrollmentConfig = GuidedEnrollmentConfig(),
        clock: @escaping () -> Date = Date.init, sleep: @escaping (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }
    ) {
        self.frames = frames
        self.sampler = sampler
        self.sessionLock = sessionLock
        self.config = config
        self.clock = clock
        self.sleep = sleep
    }

    /// Un tour complet. Retourne les empreintes retenues (de face + une par secteur).
    /// La caméra est allumée pendant le tour seulement.
    public func runScan(shouldContinue: () -> Bool = { true }, onEvent: (GuidedEnrollmentEvent) -> Void) throws -> [FaceEmbedding] {
        guard sessionLock.try() else { throw GuidedEnrollmentError.cameraBusy }
        defer { sessionLock.unlock() }
        do {
            try frames.start()
        } catch {
            throw GuidedEnrollmentError.cameraUnavailable
        }
        defer { frames.stop() }

        var embeddings: [FaceEmbedding] = []
        var baselinePoses: [FacePose] = []
        var filled = [Bool](repeating: false, count: config.sectorCount)
        let required = max(1, Int((Double(config.sectorCount) * config.requiredFraction).rounded(.up)))
        var lastSequence = 0
        var lastSampleAt = Date.distantPast
        var lastIssue: GuidedEnrollmentIssue?
        let deadline = clock().addingTimeInterval(config.scanTimeout)
        onEvent(.calibrating(captured: 0, needed: config.centerSamples))

        while filled.filter({ $0 }).count < required {
            guard shouldContinue() else { throw GuidedEnrollmentError.cancelled }
            let now = clock()
            guard now < deadline else {
                throw GuidedEnrollmentError.timedOut(filledSectors: filled.filter { $0 }.count, totalSectors: config.sectorCount)
            }
            guard now.timeIntervalSince(lastSampleAt) >= config.sampleSpacing,
                  let frame = frames.frame(newerThan: lastSequence) else {
                sleep(0.03)
                continue
            }
            lastSequence = frame.sequence
            lastSampleAt = now

            let sample: GuidedSample
            do {
                sample = try sampler.guidedSample(from: frame.image)
                lastIssue = nil
            } catch {
                let issue = Self.issue(for: error)
                if issue != lastIssue {
                    lastIssue = issue
                    onEvent(.issue(issue))
                }
                continue
            }
            guard let pose = sample.pose else { continue }

            // Position de référence : les premières images, visage de face.
            if baselinePoses.count < config.centerSamples {
                baselinePoses.append(pose)
                embeddings.append(sample.embedding)
                onEvent(.calibrating(captured: baselinePoses.count, needed: config.centerSamples))
                if baselinePoses.count == config.centerSamples {
                    onEvent(.progress(filled: filled, direction: nil))
                }
                continue
            }

            let baseline = Self.average(baselinePoses)
            let direction = Self.direction(of: pose, from: baseline, config: config)
            if let direction {
                let sector = Self.sector(for: direction, count: config.sectorCount)
                if !filled[sector] {
                    filled[sector] = true
                    embeddings.append(sample.embedding)
                }
            }
            onEvent(.progress(filled: filled, direction: direction))
        }
        return embeddings
    }

    /// Premier enrôlement : deux tours réunis en une seule apparence « Standard ».
    public func saveEnrollment(scans: [[FaceEmbedding]]) throws {
        try sampler.saveEnrollment(scans.flatMap { $0 })
    }

    /// Nouvelle apparence du même visage (refusée s'il s'agit d'une autre personne).
    public func addAppearance(named name: String, scans: [[FaceEmbedding]]) throws -> FaceAppearance {
        try sampler.addAppearance(named: name, from: scans.flatMap { $0 })
    }

    // MARK: - Calculs (testés)

    /// Direction de la tête en vue miroir (radians, 0 = droite de l'écran, sens horaire),
    /// ou `nil` si la tête est trop proche de la position de face.
    static func direction(of pose: FacePose, from baseline: FacePose, config: GuidedEnrollmentConfig) -> Double? {
        // Miroir horizontal : l'aperçu montre l'utilisateur comme dans un miroir.
        let dx = -(pose.horizontal - baseline.horizontal)
        let dy = (pose.vertical - baseline.vertical) * config.verticalGain
        guard hypot(dx, dy) >= config.minimumOffset else { return nil }
        let angle = atan2(dy, dx)
        return angle < 0 ? angle + 2 * .pi : angle
    }

    static func sector(for direction: Double, count: Int) -> Int {
        let width = 2 * Double.pi / Double(count)
        return min(count - 1, max(0, Int(direction / width)))
    }

    static func average(_ poses: [FacePose]) -> FacePose {
        let count = Double(poses.count)
        return FacePose(
            horizontal: poses.reduce(0) { $0 + $1.horizontal } / count,
            vertical: poses.reduce(0) { $0 + $1.vertical } / count
        )
    }

    static func issue(for error: Error) -> GuidedEnrollmentIssue {
        switch error {
        case VerificationPipelineError.multipleFaces: return .multipleFaces
        case VerificationPipelineError.faceTooFar: return .tooFar
        case VerificationPipelineError.notLive: return .notLive
        default: return .noFace
        }
    }
}
