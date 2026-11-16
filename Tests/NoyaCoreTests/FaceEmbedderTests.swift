import Testing
import CoreGraphics
import Foundation
@testable import NoyaCore

/// Tant que le modèle de reconnaissance n'est pas ajouté (jalon J2), son absence doit
/// produire une erreur explicite, sans repli silencieux vers un autre extracteur.
@Test(.enabled(if: ModelResources.url(named: FaceEmbedder.modelName) == nil))
func missingRecognitionModelFailsExplicitly() {
    #expect(throws: FaceEmbedderError.modelLoadFailed) {
        _ = try FaceEmbedder()
    }
}

@Test(.enabled(if: ModelResources.url(named: FaceEmbedder.modelName) != nil))
func embedderLoadsWhenModelIsBundled() throws {
    _ = try FaceEmbedder()
}

@Test func noFaceInBlankImageThrowsNoFaceDetected() throws {
    let blankImage = makeSolidColorImage(width: 200, height: 200, gray: 0.5)
    #expect(throws: FaceEmbedderError.noFaceDetected) {
        _ = try VisionFaceDetector().detectLargestFace(in: blankImage)
    }
}

func makeSolidColorImage(width: Int, height: Int, gray: CGFloat) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
    )!
    context.setFillColor(gray: gray, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

/// Fidélité de la conversion Core ML : pour l'image synthétique de scripts/convert_sface.py,
/// l'empreinte Core ML doit rester quasi identique à celle du modèle ONNX d'origine
/// (référence onnxruntime enregistrée dans Fixtures/sface_reference.json).
@Test(.enabled(if: ModelResources.url(named: FaceEmbedder.modelName) != nil))
func coreMLEmbeddingMatchesOnnxReference() throws {
    struct Reference: Decodable { let embedding: [Float] }
    let url = try #require(Bundle.module.url(forResource: "sface_reference", withExtension: "json", subdirectory: "Fixtures"))
    let reference = try JSONDecoder().decode(Reference.self, from: Data(contentsOf: url))
    #expect(reference.embedding.count == 128)

    var bytes = [UInt8](repeating: 255, count: 112 * 112 * 4)
    for y in 0..<112 {
        for x in 0..<112 {
            let offset = (y * 112 + x) * 4
            bytes[offset] = UInt8((x * 2 + y) % 256)
            bytes[offset + 1] = UInt8((y * 2 + 37) % 256)
            bytes[offset + 2] = UInt8((x + y * 3 + 101) % 256)
        }
    }
    let embedding = try FaceEmbedder().embedding(forAligned: RGBAImage(width: 112, height: 112, bytes: bytes))
    #expect(embedding.vector.count == 128)
    let similarity = EmbeddingMath.cosineSimilarity(embedding, FaceEmbedding(vector: reference.embedding))
    #expect(similarity > 0.999, "Similarité Core ML / ONNX : \(similarity)")
}
