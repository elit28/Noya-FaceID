import CoreGraphics
import CoreML
import Foundation

public enum FaceEmbedderError: Error, Equatable {
    case noFaceDetected
    case modelLoadFailed
    case inferenceFailed
}

public protocol FaceEmbedding_Provider {
    func embedding(for face: DetectedFace, in frame: RGBAImage) throws -> FaceEmbedding
}

/// Extracteur d'empreinte faciale : modèle SFace (OpenCV Zoo, Apache-2.0), converti en
/// Core ML par `scripts/convert_sface.py` et embarqué sous `FaceRecognition.mlpkgdata`.
///
/// Entrée : visage aligné en RVB 112 × 112 (valeurs 0-255) sur les 5 points de repère du
/// gabarit standard (voir `FaceGeometry`) ; la normalisation est intégrée au modèle.
/// Sortie : 128 valeurs, normalisées ici (norme L2 = 1).
///
/// NOYA Face n'embarque **aucun** modèle InsightFace/ArcFace (licence non commerciale).
/// Si le modèle est absent, `init()` lève `FaceEmbedderError.modelLoadFailed` : aucun repli
/// silencieux vers un extracteur moins fiable.
public final class FaceEmbedder: FaceEmbedding_Provider {
    /// Nom de la ressource du modèle de reconnaissance (sans extension).
    public static let modelName = "FaceRecognition"
    /// Identifiant enregistré avec chaque profil : changer de modèle impose un réenregistrement.
    public static let modelIdentifier = "SFace-2021dec-coreml-fp16"

    private let model: MLModel
    private let inputName = "input_image"
    private let outputName = "embedding"

    public init() throws {
        guard let url = ModelResources.url(named: Self.modelName) else {
            throw FaceEmbedderError.modelLoadFailed
        }
        do {
            let compiledURL = try MLModel.compileModel(at: url)
            self.model = try MLModel(contentsOf: compiledURL)
        } catch {
            throw FaceEmbedderError.modelLoadFailed
        }
    }

    public func embedding(for face: DetectedFace, in frame: RGBAImage) throws -> FaceEmbedding {
        guard face.landmarks.count == 5 else { throw FaceEmbedderError.noFaceDetected }
        return try embedding(forAligned: FaceGeometry.alignedFace(in: frame, landmarks: face.landmarks))
    }

    /// Empreinte d'un visage déjà aligné (112 × 112). Sert aussi aux tests de fidélité du modèle.
    func embedding(forAligned aligned: RGBAImage) throws -> FaceEmbedding {
        guard aligned.width == 112, aligned.height == 112,
              let pixelBuffer = aligned.makePixelBuffer(),
              let provider = try? MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(pixelBuffer: pixelBuffer)]),
              let output = try? model.prediction(from: provider),
              let multiArray = output.featureValue(for: outputName)?.multiArrayValue
        else {
            throw FaceEmbedderError.inferenceFailed
        }
        var vector = [Float](repeating: 0, count: multiArray.count)
        for i in 0..<multiArray.count { vector[i] = multiArray[i].floatValue }
        return EmbeddingMath.normalized(FaceEmbedding(vector: vector))
    }

    /// Detect-then-embed convenience for callers holding just a frame.
    public func embedding(in image: CGImage, detector: FaceDetecting = VisionFaceDetector()) throws -> FaceEmbedding {
        let face = try detector.detectLargestFace(in: image)
        guard let frame = RGBAImage(cgImage: image) else { throw FaceEmbedderError.inferenceFailed }
        return try embedding(for: face, in: frame)
    }
}
