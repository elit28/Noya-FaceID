import Testing
import Foundation
import CoreGraphics
@testable import NoyaCore

let fakeFace = DetectedFace(
    boundingBox: CGRect(x: 2, y: 2, width: 6, height: 6),
    landmarks: [CGPoint(x: 3, y: 4), CGPoint(x: 7, y: 4), CGPoint(x: 5, y: 5), CGPoint(x: 4, y: 7), CGPoint(x: 6, y: 7)]
)

final class FakeDetector: FaceDetecting {
    var shouldThrow: FaceEmbedderError?
    /// Largeur des autres visages « vus » dans l'image.
    var otherFaceWidths: [CGFloat] = []
    func detectLargestFace(in image: CGImage) throws -> DetectedFace {
        if let error = shouldThrow { throw error }
        return fakeFace
    }
    func detectFaces(in image: CGImage) throws -> FaceDetection {
        FaceDetection(primary: try detectLargestFace(in: image), otherFaceWidths: otherFaceWidths)
    }
}

final class FakeEmbedder: FaceEmbedding_Provider {
    var nextEmbedding = FaceEmbedding(vector: [1, 0, 0])
    func embedding(for face: DetectedFace, in frame: RGBAImage) throws -> FaceEmbedding { nextEmbedding }
}

final class FakeClassifier: LivenessChecking {
    var nextResult = LivenessResult(isLive: true, confidence: 0.99)
    func liveness(for face: DetectedFace, in frame: RGBAImage) throws -> LivenessResult { nextResult }
}

func makeDummyImage() -> CGImage {
    let context = CGContext(
        data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
    )!
    return context.makeImage()!
}

func makePipeline(
    embedder: FakeEmbedder = FakeEmbedder(), classifier: FakeClassifier = FakeClassifier(),
    detector: FakeDetector = FakeDetector(), config: PipelineConfig = PipelineConfig(),
    store: SecureStore = SecureStore(keyProvider: FakeKeyProvider(), directory: makeTempDirectory()),
    modelIdentifier: String = FaceEmbedder.modelIdentifier
) -> VerificationPipeline {
    VerificationPipeline(detector: detector, embedder: embedder, classifier: classifier, store: store, config: config,
                         modelIdentifier: modelIdentifier)
}

@Test func enrollThenVerifyWithSameFaceSucceeds() throws {
    let embedder = FakeEmbedder()
    let pipeline = makePipeline(embedder: embedder)
    try pipeline.enroll(images: [makeDummyImage(), makeDummyImage()])
    #expect(try pipeline.verify(image: makeDummyImage()) == true)
}

@Test func verifyWithDifferentFaceFails() throws {
    let embedder = FakeEmbedder()
    let pipeline = makePipeline(embedder: embedder)
    try pipeline.enroll(images: [makeDummyImage()])
    embedder.nextEmbedding = FaceEmbedding(vector: [0, 1, 0])
    #expect(try pipeline.verify(image: makeDummyImage()) == false)
}

@Test func verifyFailsWhenLivenessCheckFails() throws {
    let classifier = FakeClassifier()
    let pipeline = makePipeline(classifier: classifier)
    try pipeline.enroll(images: [makeDummyImage()])
    classifier.nextResult = LivenessResult(isLive: false, confidence: 0.1)
    #expect(try pipeline.verify(image: makeDummyImage()) == false)
}

@Test func verifyFailsWhenLivenessConfidenceBelowThreshold() throws {
    let classifier = FakeClassifier()
    let pipeline = makePipeline(classifier: classifier)
    try pipeline.enroll(images: [makeDummyImage()])
    classifier.nextResult = LivenessResult(isLive: true, confidence: 0.5)
    #expect(try pipeline.verify(image: makeDummyImage()) == false)
}

@Test func enrollmentRejectsFramesThatFailLiveness() throws {
    let classifier = FakeClassifier()
    classifier.nextResult = LivenessResult(isLive: false, confidence: 0.02)
    let pipeline = makePipeline(classifier: classifier)
    #expect(throws: VerificationPipelineError.notLive(confidence: 0.02)) {
        _ = try pipeline.enrollmentSample(from: makeDummyImage())
    }
}

@Test func verifyBeforeEnrollmentThrows() throws {
    #expect(throws: SecureStoreError.notFound) {
        _ = try makePipeline().verify(image: makeDummyImage())
    }
}

@Test func enrollWithEmptyImagesThrowsCleanly() throws {
    #expect(throws: VerificationPipelineError.noImagesProvided) {
        try makePipeline().enroll(images: [])
    }
}

@Test func noFaceDetectedPropagates() throws {
    let detector = FakeDetector()
    detector.shouldThrow = .noFaceDetected
    let pipeline = makePipeline(detector: detector)
    #expect(throws: FaceEmbedderError.noFaceDetected) {
        try pipeline.enroll(images: [makeDummyImage()])
    }
}

@Test func enrolledCentroidIsUnitLength() throws {
    let embedder = FakeEmbedder()
    embedder.nextEmbedding = FaceEmbedding(vector: [3, 4, 0])
    let pipeline = makePipeline(embedder: embedder)
    try pipeline.enroll(images: [makeDummyImage()])
    let profile = try pipeline.loadProfile()
    #expect(profile.appearances.count == 1)
    #expect(profile.appearances[0].name == VerificationPipeline.defaultAppearanceName)
    let centroid = profile.appearances[0].centroid
    #expect(abs(centroid.reduce(0) { $0 + $1 * $1 } - 1) < 1e-5)
}

@Test func verifyFailsCleanlyWhenStoredCentroidDimensionMismatches() throws {
    let embedder = FakeEmbedder()
    let pipeline = makePipeline(embedder: embedder)
    try pipeline.enroll(images: [makeDummyImage()])
    embedder.nextEmbedding = FaceEmbedding(vector: [1, 0, 0, 0, 0])
    #expect(try pipeline.verify(image: makeDummyImage()) == false)
}

// MARK: - Un visage, plusieurs apparences ; refus multi-visages et distance

@Test func verificationIsRefusedWhenAnotherSignificantFaceIsVisible() throws {
    let detector = FakeDetector()
    let pipeline = makePipeline(detector: detector)
    try pipeline.enroll(images: [makeDummyImage()])
    detector.otherFaceWidths = [fakeFace.boundingBox.width * 0.8]
    #expect(throws: VerificationPipelineError.multipleFaces) {
        _ = try pipeline.verify(image: makeDummyImage())
    }
}

@Test func smallFaceFarInTheBackgroundIsIgnored() throws {
    let detector = FakeDetector()
    let pipeline = makePipeline(detector: detector)
    try pipeline.enroll(images: [makeDummyImage()])
    detector.otherFaceWidths = [fakeFace.boundingBox.width * 0.2]
    #expect(try pipeline.verify(image: makeDummyImage()) == true)
}

@Test func faceTooSmallInTheFrameIsRefused() throws {
    let pipeline = makePipeline(config: PipelineConfig(minimumFaceWidthFraction: 0.9))
    #expect(throws: VerificationPipelineError.faceTooFar) {
        _ = try pipeline.enrollmentSample(from: makeDummyImage())
    }
}

@Test func appearanceOfTheSamePersonIsAddedAndUsed() throws {
    let embedder = FakeEmbedder()
    embedder.nextEmbedding = FaceEmbedding(vector: [1, 0, 0])
    let pipeline = makePipeline(embedder: embedder)
    try pipeline.enroll(images: [makeDummyImage()])
    // Même personne avec des lunettes : proche, mais pas identique.
    let glasses = EmbeddingMath.normalized(FaceEmbedding(vector: [0.8, 0.6, 0]))
    let added = try pipeline.addAppearance(named: "Avec lunettes", from: [glasses])
    #expect(try pipeline.loadProfile().appearances.map(\.name) == [VerificationPipeline.defaultAppearanceName, "Avec lunettes"])
    #expect(added.isEnabled)
    embedder.nextEmbedding = glasses
    #expect(try pipeline.verify(image: makeDummyImage()) == true)
}

@Test func appearanceOfAnotherPersonIsRejected() throws {
    let embedder = FakeEmbedder()
    embedder.nextEmbedding = FaceEmbedding(vector: [1, 0, 0])
    let pipeline = makePipeline(embedder: embedder)
    try pipeline.enroll(images: [makeDummyImage()])
    #expect(throws: VerificationPipelineError.differentPerson) {
        try pipeline.addAppearance(named: "Autre personne", from: [FaceEmbedding(vector: [0, 1, 0])])
    }
    #expect(try pipeline.loadProfile().appearances.count == 1)
}

@Test func disabledAppearanceNoLongerMatches() throws {
    let embedder = FakeEmbedder()
    embedder.nextEmbedding = FaceEmbedding(vector: [1, 0, 0])
    let pipeline = makePipeline(embedder: embedder)
    try pipeline.enroll(images: [makeDummyImage()])
    var profile = try pipeline.loadProfile()
    profile.appearances[0].isEnabled = false
    try pipeline.saveProfile(profile)
    #expect(try pipeline.verify(image: makeDummyImage()) == false)
}

@Test func profileFromAnotherModelMustBeEnrolledAgain() throws {
    let store = SecureStore(keyProvider: FakeKeyProvider(), directory: makeTempDirectory())
    try makePipeline(store: store, modelIdentifier: "ancien-modele").enroll(images: [makeDummyImage()])
    #expect(throws: VerificationPipelineError.staleEnrollment) {
        _ = try makePipeline(store: store).loadProfile()
    }
}

@Test func corruptProfileIsReportedNotTrusted() throws {
    let store = SecureStore(keyProvider: FakeKeyProvider(), directory: makeTempDirectory())
    try store.save(Data("pas du JSON".utf8), as: VerificationPipeline.profileKey)
    #expect(throws: VerificationPipelineError.corruptEnrollment) {
        _ = try makePipeline(store: store).loadProfile()
    }
}

@Test func profileMatchRequiresCentroidAndBestSample() {
    let appearance = FaceAppearance(name: "Standard", centroid: [1, 0, 0], samples: [[0, 1, 0]])
    let profile = FaceProfile(model: FaceEmbedder.modelIdentifier, appearances: [appearance])
    let match = profile.bestMatch(for: FaceEmbedding(vector: [1, 0, 0]))
    #expect(match?.centroidSimilarity == 1)
    #expect(match?.passes(threshold: 0.42) == false)
}
