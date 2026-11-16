import CoreGraphics
import Foundation
import NoyaCore

public struct VerificationOutcome: Equatable, Sendable {
    public var matched = false
    public var framesEvaluated = 0
    public var framesWithoutFace = 0
    public var bestSimilarity: Float = -1
    public var bestLiveness: Float = 0
    public var failure: String?
    public var mismatched = false
    public var wrongFaceFrames = 0
    public var longestWrongStreak = 0
    public var matchThreshold: Float = 0
    /// Images refusées parce que plusieurs visages étaient visibles.
    public var framesWithMultipleFaces = 0
    /// Images où le visage était trop petit (trop loin).
    public var framesTooFar = 0

    public init() {}

    public var debugSummary: String {
        String(format: "faceFrames=%d noFaceFrames=%d wrongFaceFrames=%d longestWrongStreak=%d/%d bestSimilarity=%.3f threshold=%.2f bestLiveness=%.3f multipleFaceFrames=%d tooFarFrames=%d",
               framesEvaluated, framesWithoutFace, wrongFaceFrames, longestWrongStreak, FaceVerifier.mismatchFrames,
               bestSimilarity, matchThreshold, bestLiveness, framesWithMultipleFaces, framesTooFar)
    }

    public var summary: String {
        if let failure { return "FAIL (\(failure))" }
        let scores = String(format: "frames=%d noFace=%d bestSimilarity=%.3f bestLiveness=%.3f",
                            framesEvaluated, framesWithoutFace, bestSimilarity, bestLiveness)
        return (matched ? "OK " : "FAIL ") + scores
    }
}

public protocol FaceMatching: AnyObject {
    func run(timeout: TimeInterval, requiredConsecutive: Int, waitForTurn: TimeInterval,
             keepGoing: () -> Bool) -> VerificationOutcome
}

/// Runs a bounded verification window over live camera frames. A match needs
/// `requiredConsecutive` consecutive frames that are both live and above the similarity
/// threshold, so one lucky frame can't unlock. `sessionLock` is shared by everything that
/// uses the camera, so only one window or enrollment runs at a time.
public final class FaceVerifier: FaceMatching, @unchecked Sendable {
    private let camera: FrameSource
    private let pipeline: VerificationPipeline
    private let sessionLock: NSLock
    static let mismatchFrames = 6

    public init(camera: FrameSource, pipeline: VerificationPipeline, sessionLock: NSLock = NSLock()) {
        self.camera = camera
        self.pipeline = pipeline
        self.sessionLock = sessionLock
    }

    public func run(
        timeout: TimeInterval, requiredConsecutive: Int = 2, waitForTurn: TimeInterval = 0,
        keepGoing: () -> Bool = { true }
    ) -> VerificationOutcome {
        var outcome = VerificationOutcome()
        guard sessionLock.lock(before: Date().addingTimeInterval(waitForTurn)) else {
            outcome.failure = "camera busy with another verification"
            return outcome
        }
        defer { sessionLock.unlock() }

        // Le profil est chargé avant d'allumer la caméra : sans enrôlement ou sans accès à la
        // clé, l'échec est immédiat et le voyant de la caméra ne s'allume pas.
        let profile: FaceProfile
        do {
            profile = try pipeline.loadProfile()
        } catch VerificationPipelineError.staleEnrollment {
            outcome.failure = "enrollment made with another model: enroll your face again"
            return outcome
        } catch KeychainKeyProviderError.interactionRequired {
            outcome.failure = "keychain access needs approval: open NOYA Face and run the face test"
            return outcome
        } catch SecureStoreError.notFound {
            outcome.failure = "not enrolled"
            return outcome
        } catch {
            outcome.failure = "enrollment unavailable: \(error)"
            return outcome
        }

        let deadline = Date().addingTimeInterval(timeout)
        do {
            try camera.start()
        } catch {
            outcome.failure = "camera unavailable: \(error)"
            return outcome
        }
        defer { camera.stop() }

        var lastSequence = 0
        outcome.matchThreshold = pipeline.config.matchThreshold
        var consecutive = 0
        var wrongStreak = 0
        while Date() < deadline, keepGoing() {
            guard let frame = camera.frame(newerThan: lastSequence) else {
                Thread.sleep(forTimeInterval: 0.03)
                continue
            }
            lastSequence = frame.sequence
            do {
                let evaluation = try pipeline.evaluate(image: frame.image, against: profile)
                outcome.framesEvaluated += 1
                outcome.bestSimilarity = max(outcome.bestSimilarity, evaluation.similarity)
                outcome.bestLiveness = max(outcome.bestLiveness, evaluation.liveness)
                consecutive = evaluation.accepted ? consecutive + 1 : 0
                wrongStreak = evaluation.isMatch ? 0 : wrongStreak + 1
                if !evaluation.isMatch { outcome.wrongFaceFrames += 1 }
                outcome.longestWrongStreak = max(outcome.longestWrongStreak, wrongStreak)
                if consecutive >= requiredConsecutive {
                    outcome.matched = true
                    return outcome
                }
                if wrongStreak >= Self.mismatchFrames {
                    outcome.mismatched = true
                    return outcome
                }
            } catch VerificationPipelineError.multipleFaces {
                outcome.framesWithMultipleFaces += 1
                consecutive = 0
            } catch VerificationPipelineError.faceTooFar {
                outcome.framesTooFar += 1
                consecutive = 0
                wrongStreak = 0
            } catch {
                outcome.framesWithoutFace += 1
                consecutive = 0
                wrongStreak = 0
            }
        }
        return outcome
    }
}
