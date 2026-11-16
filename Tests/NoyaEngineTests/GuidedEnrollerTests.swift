import CoreGraphics
import Foundation
import NoyaCore
import Testing
@testable import NoyaEngine

private final class GuidedFrames: FrameSource {
    private(set) var started = 0
    private(set) var stopped = 0
    private var sequence = 0
    var startError: Error?

    func start() throws {
        if let startError { throw startError }
        started += 1
    }

    func stop() { stopped += 1 }

    func frame(newerThan sequence: Int) -> (image: CGImage, sequence: Int)? {
        self.sequence += 1
        return (makeTestImage(), self.sequence)
    }
}

/// Simule une tête qui reste de face, puis tourne en cercle.
private final class CirclingSampler: GuidedEnrollmentSampling {
    var steps: [Result<FacePose, Error>]
    private(set) var saved: [FaceEmbedding]?
    private(set) var added: [FaceEmbedding]?

    init(steps: [Result<FacePose, Error>]) { self.steps = steps }

    func guidedSample(from image: CGImage) throws -> GuidedSample {
        let step = steps.isEmpty ? .success(FacePose(horizontal: 0, vertical: 0.55)) : steps.removeFirst()
        let pose = try step.get()
        return GuidedSample(
            embedding: FaceEmbedding(vector: [1, Float(pose.horizontal), Float(pose.vertical)]),
            liveness: LivenessResult(isLive: true, confidence: 0.99), pose: pose
        )
    }

    func saveEnrollment(_ embeddings: [FaceEmbedding]) throws -> FaceEmbedding {
        saved = embeddings
        return embeddings[0]
    }

    func addAppearance(named name: String, from embeddings: [FaceEmbedding]) throws -> FaceAppearance {
        added = embeddings
        return try FaceAppearance.make(name: name, from: embeddings)
    }
}

private final class StepClock {
    private var now = Date(timeIntervalSince1970: 1_000)
    func read() -> Date { now }
    func sleep(_ interval: TimeInterval) { now = now.addingTimeInterval(max(interval, 0.05)) }
    func advance(_ interval: TimeInterval) { now = now.addingTimeInterval(interval) }
}

/// Position de face, puis un tour complet par pas de 15° (vue miroir).
private func circlingSteps(center: Int = 3, radius: Double = 0.2) -> [Result<FacePose, Error>] {
    let neutral = FacePose(horizontal: 0, vertical: 0.55)
    var steps = [Result<FacePose, Error>](repeating: .success(neutral), count: center)
    for degrees in stride(from: 7.5, to: 360, by: 15) {
        let angle = degrees * .pi / 180
        // Vue miroir : direction écran (cos, sin) ⇒ décalage image horizontal = -cos.
        steps.append(.success(FacePose(horizontal: -radius * cos(angle), vertical: 0.55 + radius * sin(angle) / 2)))
    }
    return steps
}

private func makeGuidedEnroller(frames: GuidedFrames, sampler: CirclingSampler, clock: StepClock,
                                config: GuidedEnrollmentConfig = GuidedEnrollmentConfig()) -> GuidedEnroller {
    let advancing: (TimeInterval) -> Void = { clock.sleep($0) }
    return GuidedEnroller(frames: frames, sampler: sampler, config: config,
                          clock: { clock.advance(0.2); return clock.read() }, sleep: advancing)
}

@Test func fullHeadCircleFillsEverySectorAndKeepsOneSamplePerSector() throws {
    let frames = GuidedFrames()
    let sampler = CirclingSampler(steps: circlingSteps())
    let enroller = makeGuidedEnroller(frames: frames, sampler: sampler, clock: StepClock())
    var lastFilled: [Bool] = []
    let embeddings = try enroller.runScan { event in
        if case .progress(let filled, _) = event { lastFilled = filled }
    }
    #expect(lastFilled.count == 12)
    #expect(lastFilled.allSatisfy { $0 })
    #expect(embeddings.count == 3 + 12)
    #expect(frames.started == 1)
    #expect(frames.stopped == 1)
}

@Test func headTurnedTowardTheScreenRightLightsTheRightSector() {
    let config = GuidedEnrollmentConfig()
    let baseline = FacePose(horizontal: 0, vertical: 0.55)
    // Tête tournée vers sa droite : dans l'image (non miroir), le nez part vers la gauche.
    let turned = FacePose(horizontal: -0.3, vertical: 0.55)
    let direction = GuidedEnroller.direction(of: turned, from: baseline, config: config)
    #expect(direction != nil)
    #expect(GuidedEnroller.sector(for: direction ?? -1, count: 12) == 0)
    #expect(GuidedEnroller.direction(of: FacePose(horizontal: 0.02, vertical: 0.56), from: baseline, config: config) == nil)
}

@Test func multipleFacesAreReportedOnceWhileTheyPersist() throws {
    let frames = GuidedFrames()
    let steps: [Result<FacePose, Error>] = [
        .failure(VerificationPipelineError.multipleFaces), .failure(VerificationPipelineError.multipleFaces),
    ] + circlingSteps()
    let sampler = CirclingSampler(steps: steps)
    var issues: [GuidedEnrollmentIssue] = []
    _ = try makeGuidedEnroller(frames: frames, sampler: sampler, clock: StepClock()).runScan { event in
        if case .issue(let issue) = event { issues.append(issue) }
    }
    #expect(issues == [.multipleFaces])
}

@Test func scanTimesOutWhenTheHeadNeverTurns() {
    let frames = GuidedFrames()
    let sampler = CirclingSampler(steps: [])
    var config = GuidedEnrollmentConfig()
    config.scanTimeout = 5
    let enroller = makeGuidedEnroller(frames: frames, sampler: sampler, clock: StepClock(), config: config)
    #expect(throws: GuidedEnrollmentError.timedOut(filledSectors: 0, totalSectors: 12)) {
        _ = try enroller.runScan { _ in }
    }
    #expect(frames.stopped == 1)
}

@Test func partialCircleOptionNeedsHalfTheSectors() throws {
    let frames = GuidedFrames()
    // Seulement la moitié droite du cercle (de -90° à +90°).
    let neutral = FacePose(horizontal: 0, vertical: 0.55)
    var steps = [Result<FacePose, Error>](repeating: .success(neutral), count: 3)
    for degrees in stride(from: -82.5, to: 90, by: 15) {
        let angle = degrees * .pi / 180
        steps.append(.success(FacePose(horizontal: -0.2 * cos(angle), vertical: 0.55 + 0.2 * sin(angle) / 2)))
    }
    let sampler = CirclingSampler(steps: steps)
    let embeddings = try makeGuidedEnroller(frames: frames, sampler: sampler, clock: StepClock(),
                                            config: .partialCircle).runScan { _ in }
    #expect(embeddings.count >= 3 + 6)
}

@Test func cameraBusyIsReportedWithoutStartingTheCamera() {
    let frames = GuidedFrames()
    let lock = NSLock()
    lock.lock()
    defer { lock.unlock() }
    let enroller = GuidedEnroller(frames: frames, sampler: CirclingSampler(steps: []), sessionLock: lock)
    #expect(throws: GuidedEnrollmentError.cameraBusy) {
        _ = try enroller.runScan { _ in }
    }
    #expect(frames.started == 0)
}

@Test func twoScansAreSavedAsOneAppearance() throws {
    let sampler = CirclingSampler(steps: [])
    let enroller = GuidedEnroller(frames: GuidedFrames(), sampler: sampler)
    try enroller.saveEnrollment(scans: [[FaceEmbedding(vector: [1, 0, 0])], [FaceEmbedding(vector: [0.9, 0.1, 0])]])
    #expect(sampler.saved?.count == 2)
}
