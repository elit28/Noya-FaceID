import CoreGraphics
import Foundation

/// Orientation approximative de la tête, estimée à partir des 5 points de repère du visage
/// (yeux, nez, coins de la bouche). Sert à guider l'enrôlement « tournez la tête » ; ce n'est
/// pas une mesure d'angle précise.
///
/// Repère de l'image : x vers la droite, y vers le bas. Valeurs relatives, à comparer à une
/// position de référence (le visage de face au début de l'enrôlement).
public struct FacePose: Equatable, Sendable {
    /// Décalage horizontal du nez par rapport au milieu des yeux, rapporté à l'écart entre
    /// les yeux. Proche de 0 de face.
    public let horizontal: Double
    /// Position verticale du nez entre la ligne des yeux (0) et celle de la bouche (1).
    public let vertical: Double

    public init(horizontal: Double, vertical: Double) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    /// `landmarks` dans l'ordre du gabarit : œil gauche de l'image, œil droit, nez,
    /// coin gauche de la bouche, coin droit.
    public static func estimate(from landmarks: [CGPoint]) -> FacePose? {
        guard landmarks.count == 5 else { return nil }
        let eyeLeft = landmarks[0], eyeRight = landmarks[1], nose = landmarks[2]
        let mouthLeft = landmarks[3], mouthRight = landmarks[4]
        let eyeMid = CGPoint(x: (eyeLeft.x + eyeRight.x) / 2, y: (eyeLeft.y + eyeRight.y) / 2)
        let mouthMid = CGPoint(x: (mouthLeft.x + mouthRight.x) / 2, y: (mouthLeft.y + mouthRight.y) / 2)
        let interocular = hypot(eyeRight.x - eyeLeft.x, eyeRight.y - eyeLeft.y)
        let faceHeight = mouthMid.y - eyeMid.y
        guard interocular > 0, faceHeight > 0 else { return nil }
        return FacePose(
            horizontal: Double((nose.x - eyeMid.x) / interocular),
            vertical: Double((nose.y - eyeMid.y) / faceHeight)
        )
    }
}

/// Un échantillon d'enrôlement guidé : empreinte, présence réelle et orientation de la tête.
public struct GuidedSample: Sendable {
    public let embedding: FaceEmbedding
    public let liveness: LivenessResult
    public let pose: FacePose?

    public init(embedding: FaceEmbedding, liveness: LivenessResult, pose: FacePose?) {
        self.embedding = embedding
        self.liveness = liveness
        self.pose = pose
    }
}
