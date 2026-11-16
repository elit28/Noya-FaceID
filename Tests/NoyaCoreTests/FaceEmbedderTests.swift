import Testing
import CoreGraphics
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
