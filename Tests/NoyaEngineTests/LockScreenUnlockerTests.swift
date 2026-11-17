import Testing
import Foundation
import NoyaCore
@testable import NoyaEngine

private func makeUnlocker(
    system: FakeSystem, matcher: FakeMatcher, typist: PasswordTyping, settings: EngineSettings, recorder: EventRecorder
) -> LockScreenUnlocker {
    LockScreenUnlocker(
        matcher: matcher, typist: typist, settings: settings,
        environment: system.environment(), onEvent: { recorder.record($0) }
    )
}

@Test func typesThePasswordWhenTheFaceMatches() {
    let system = FakeSystem()
    let matcher = FakeMatcher()
    matcher.outcome = matchedOutcome()
    let typist = FakeTypist(system: system, unlocks: true)
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let recorder = EventRecorder()
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: typist, settings: settings, recorder: recorder)

    #expect(unlocker.tick() == .unlocked)
    #expect(typist.typed == ["hunter2"])
    #expect(recorder.events == [.lockScreenScanning, .lockScreenUnlocked(summary: matchedOutcome().summary)])
    #expect(settings.lockScreenNeedsPassword == false)
}

@Test func aRejectedPasswordStopsFurtherTyping() {
    let system = FakeSystem()
    let matcher = FakeMatcher()
    matcher.outcome = matchedOutcome()
    let typist = FakeTypist(system: system, unlocks: false)
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let recorder = EventRecorder()
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: typist, settings: settings, recorder: recorder)

    #expect(unlocker.tick() == .passwordRejected)
    #expect(settings.lockScreenNeedsPassword == true)
    #expect(recorder.events == [.lockScreenScanning, .lockScreenPasswordRejected])

    // Same lock episode: no second attempt.
    #expect(unlocker.tick() == .alreadyAttempted)
    // A new lock episode still refuses, because the stored password is known bad.
    system.locked = false
    #expect(unlocker.tick() == .notLocked)
    system.locked = true
    #expect(unlocker.tick() == .blocked(VerificationGate.passwordRejected))
    #expect(typist.typed.count == 1)
}

@Test func pausedNeverTouchesTheCamera() {
    let system = FakeSystem()
    let matcher = FakeMatcher()
    matcher.outcome = matchedOutcome()
    let typist = FakeTypist(system: system, unlocks: true)
    let settings = makeTestSettings {
        $0.lockScreenEnabled = true
        $0.paused = true
    }
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: typist, settings: settings, recorder: EventRecorder())

    #expect(unlocker.tick() == .blocked("paused"))
    #expect(matcher.callCount == 0)
    #expect(typist.typed.isEmpty)
}

@Test func missingAccessibilityIsReportedOnce() {
    let system = FakeSystem()
    system.accessibilityTrusted = false
    let matcher = FakeMatcher()
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let recorder = EventRecorder()
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: FakeTypist(system: system, unlocks: true), settings: settings, recorder: recorder)

    #expect(unlocker.tick() == .blocked(VerificationGate.accessibilityMissing))
    #expect(unlocker.tick() == .blocked(VerificationGate.accessibilityMissing))
    #expect(recorder.events == [.lockScreenProblem(VerificationGate.accessibilityMissing)])
    #expect(matcher.callCount == 0)
}

@Test func aSleepingDisplayKeepsTheCameraOff() {
    let system = FakeSystem()
    system.displayAwake = false
    let matcher = FakeMatcher()
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: FakeTypist(system: system, unlocks: true), settings: settings, recorder: EventRecorder())

    #expect(unlocker.tick() == .displayAsleep)
    #expect(matcher.callCount == 0)
}

@Test func anUnknownLockStateNeverTypes() {
    let system = FakeSystem()
    system.locked = nil
    let matcher = FakeMatcher()
    matcher.outcome = matchedOutcome()
    let typist = FakeTypist(system: system, unlocks: true)
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: typist, settings: settings, recorder: EventRecorder())

    #expect(unlocker.tick() == .notLocked)
    #expect(typist.typed.isEmpty)
}

private struct ThrowingTypist: PasswordTyping {
    struct Failure: Error {}
    func typeAndReturn(_ text: String) throws { throw Failure() }
}

@Test func aScanWithNoFaceClosesQuietly() {
    let system = FakeSystem()
    let matcher = FakeMatcher()
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let recorder = EventRecorder()
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: FakeTypist(system: system, unlocks: true), settings: settings, recorder: recorder)

    #expect(unlocker.tick() == .noMatch)
    #expect(recorder.events == [.lockScreenScanning, .lockScreenNoFace(details: matcher.outcome.debugSummary)])
    #expect(system.slept.reduce(0, +) >= LockScreenUnlocker.noFaceCooldown)
}

@Test func aWrongFaceShowsTheFailure() {
    let system = FakeSystem()
    let matcher = FakeMatcher()
    matcher.outcome.mismatched = true
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let recorder = EventRecorder()
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: FakeTypist(system: system, unlocks: true), settings: settings, recorder: recorder)

    #expect(unlocker.tick() == .noMatch)
    #expect(recorder.events == [.lockScreenScanning, .lockScreenNoMatch(details: matcher.outcome.debugSummary)])
    #expect(system.slept.reduce(0, +) >= LockScreenUnlocker.noMatchCooldown)
}

@Test func scanningStopsAfterOneRetryPerLock() {
    let system = FakeSystem()
    let matcher = FakeMatcher()
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let recorder = EventRecorder()
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: FakeTypist(system: system, unlocks: true), settings: settings, recorder: recorder)

    #expect(unlocker.tick() == .noMatch)
    #expect(unlocker.tick() == .noMatch)
    #expect(unlocker.tick() == .retriesExhausted)
    #expect(matcher.callCount == 2)

    system.locked = false
    #expect(unlocker.tick() == .notLocked)
    system.locked = true
    #expect(unlocker.tick() == .noMatch)
    #expect(matcher.callCount == 3)
}

@Test func aScanCutShortByAnUnlockJustClosesTheIndicator() {
    let system = FakeSystem()
    let matcher = FakeMatcher()
    matcher.onRun = { system.locked = false }  // unlocked another way while scanning
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let recorder = EventRecorder()
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: FakeTypist(system: system, unlocks: true), settings: settings, recorder: recorder)

    #expect(unlocker.tick() == .noMatch)
    #expect(recorder.events == [.lockScreenScanning, .lockScreenScanEnded])
}

@Test func aSuccessfulUnlockDoesNotEmitScanEnded() {
    let system = FakeSystem()
    let matcher = FakeMatcher()
    matcher.outcome = matchedOutcome()
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let recorder = EventRecorder()
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: FakeTypist(system: system, unlocks: true), settings: settings, recorder: recorder)

    #expect(unlocker.tick() == .unlocked)
    #expect(!recorder.events.contains(.lockScreenScanEnded))
}

@Test func aTypingFailureClosesTheIndicator() {
    let system = FakeSystem()
    let matcher = FakeMatcher()
    matcher.outcome = matchedOutcome()
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let recorder = EventRecorder()
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: ThrowingTypist(), settings: settings, recorder: recorder)

    guard case .typingFailed = unlocker.tick() else { Issue.record("expected .typingFailed"); return }
    #expect(recorder.events == [.lockScreenScanning, .lockScreenScanEnded])
}

@Test func aDisarmedUnlockerNeverTurnsTheCameraOn() {
    let system = FakeSystem()
    system.armed = false
    let matcher = FakeMatcher()
    matcher.outcome = matchedOutcome()
    let typist = FakeTypist(system: system, unlocks: true)
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let recorder = EventRecorder()
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: typist, settings: settings, recorder: recorder)

    #expect(unlocker.tick() == .blocked(VerificationGate.disarmed))
    #expect(matcher.callCount == 0)
    #expect(typist.typed.isEmpty)
    #expect(recorder.events.isEmpty)
}

@Test func thePasswordIsOnlyDecryptedAfterAMatch() {
    let system = FakeSystem()
    system.passwordError = SecureStoreError.decryptionFailed
    let matcher = FakeMatcher() // aucun visage reconnu
    let typist = FakeTypist(system: system, unlocks: true)
    let settings = makeTestSettings { $0.lockScreenEnabled = true }
    let recorder = EventRecorder()
    let unlocker = makeUnlocker(system: system, matcher: matcher, typist: typist, settings: settings, recorder: recorder)

    // Sans correspondance, le mot de passe n'est jamais lu : aucune erreur de stockage signalée.
    #expect(unlocker.tick() == .noMatch)
    #expect(!recorder.events.contains { if case .lockScreenProblem = $0 { return true }; return false })

    matcher.outcome = matchedOutcome()
    system.locked = false
    unlocker.tick()
    system.locked = true
    // Correspondance : la lecture échoue alors, et rien n'est tapé.
    #expect(unlocker.tick() == .blocked("stored password unavailable (\(SecureStoreError.decryptionFailed))"))
    #expect(typist.typed.isEmpty)
}

// MARK: - Approche (souris, trackpad, touche, réveil de l'écran)

private func makeApproachUnlocker(
    system: FakeSystem, matcher: FakeMatcher, typist: PasswordTyping, recorder: EventRecorder
) -> LockScreenUnlocker {
    LockScreenUnlocker(
        matcher: matcher, typist: typist, settings: makeTestSettings { $0.lockScreenEnabled = true },
        environment: system.environment(), requiresApproach: true, onEvent: { recorder.record($0) }
    )
}

@Test func lockingInFrontOfTheCameraDoesNotUnlockImmediately() {
    let system = FakeSystem()
    system.idle = 0.2 // ⌃⌘Q vient d'être pressé
    let matcher = FakeMatcher()
    matcher.outcome = matchedOutcome()
    let typist = FakeTypist(system: system, unlocks: true)
    let unlocker = makeApproachUnlocker(system: system, matcher: matcher, typist: typist, recorder: EventRecorder())

    #expect(unlocker.tick() == .waitingForApproach)
    #expect(matcher.callCount == 0)
}

@Test func touchingTheTrackpadAfterAQuietMomentStartsRecognition() {
    let system = FakeSystem()
    let matcher = FakeMatcher()
    matcher.outcome = matchedOutcome()
    let typist = FakeTypist(system: system, unlocks: true)
    let unlocker = makeApproachUnlocker(system: system, matcher: matcher, typist: typist, recorder: EventRecorder())

    system.idle = 40 // l'utilisateur est parti
    #expect(unlocker.tick() == .waitingForApproach)
    system.idle = 0.3 // il revient et touche le trackpad
    #expect(unlocker.tick() == .unlocked)
    #expect(typist.typed == ["hunter2"])
}

@Test func wakingTheDisplayStartsRecognition() {
    let system = FakeSystem()
    let matcher = FakeMatcher()
    matcher.outcome = matchedOutcome()
    let typist = FakeTypist(system: system, unlocks: true)
    let unlocker = makeApproachUnlocker(system: system, matcher: matcher, typist: typist, recorder: EventRecorder())

    system.displayAwake = false
    #expect(unlocker.tick() == .waitingForApproach)
    system.displayAwake = true
    #expect(unlocker.tick() == .unlocked)
}

@Test func eachApproachGivesNewAttemptsAfterFailures() {
    let system = FakeSystem()
    let matcher = FakeMatcher() // personne devant la caméra
    let typist = FakeTypist(system: system, unlocks: true)
    let unlocker = makeApproachUnlocker(system: system, matcher: matcher, typist: typist, recorder: EventRecorder())

    system.idle = 10
    unlocker.tick()
    system.idle = 0.1
    #expect(unlocker.tick() == .noMatch)
    #expect(unlocker.tick() == .noMatch)
    #expect(unlocker.tick() == .retriesExhausted)
    #expect(unlocker.tick() == .waitingForApproach)
    #expect(matcher.callCount == LockScreenUnlocker.maxScansPerEpisode)

    // Plus tard, l'utilisateur revient : nouveaux essais.
    system.idle = 20
    unlocker.tick()
    system.idle = 0.5
    matcher.outcome = matchedOutcome()
    #expect(unlocker.tick() == .unlocked)
}
