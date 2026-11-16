import CoreGraphics
import Testing
@testable import NoyaCore
@testable import NoyaEngine

private let config = AwayLockConfig(idleDelay: 120, retryInterval: 15, missesBeforeLock: 2)

@Test func noCheckWhileTheUserIsActive() {
    var state = AwayLockState(config: config)
    #expect(state.next(idle: 0) == .wait(120))
    #expect(state.next(idle: 119) == .wait(1))
}

@Test func locksAfterConsecutiveMisses() {
    var state = AwayLockState(config: config)
    #expect(state.next(idle: 120) == .check)
    state.record(.absent, idle: 121)
    #expect(state.next(idle: 130) == .wait(6))
    #expect(state.next(idle: 136) == .check)
    state.record(.absent, idle: 137)
    #expect(state.next(idle: 138) == .lock)
}

@Test func confirmedPresenceWaitsTheWholeDelayAgain() {
    var state = AwayLockState(config: config)
    #expect(state.next(idle: 120) == .check)
    state.record(.absent, idle: 121)
    state.record(.present, idle: 137)
    #expect(state.misses == 0)
    #expect(state.next(idle: 200) == .wait(57))
    #expect(state.next(idle: 257) == .check)
}

@Test func inconclusiveChecksNeverLock() {
    var state = AwayLockState(config: config)
    var idle: Double = 120
    for _ in 0..<10 {
        #expect(state.next(idle: idle) == .check)
        state.record(.inconclusive, idle: idle)
        idle += 15
    }
    #expect(state.misses == 0)
}

@Test func activityResetsMisses() {
    var state = AwayLockState(config: config)
    state.record(.absent, idle: 121)
    #expect(state.misses == 1)
    #expect(state.next(idle: 3) == .wait(117))
    #expect(state.misses == 0)
    #expect(state.next(idle: 120) == .check)
}

@Test func atLeastOneMissIsRequired() {
    #expect(AwayLockConfig(missesBeforeLock: 0).missesBeforeLock == 1)
}

@Test func presenceCheckToleratesDistanceAndOtherFaces() {
    let presence = NoyaRuntime.presenceConfig(strictness: .normal)
    #expect(presence.rejectMultipleFaces == false)
    #expect(presence.minimumFaceWidthFraction == CGFloat(DetectionDistance.far.minimumFaceWidthFraction))
    #expect(presence.matchThreshold == MatchStrictness.normal.threshold)
    // Les apps protégées et l'écran verrouillé, eux, refusent toujours plusieurs visages.
    #expect(NoyaRuntime.config(strictness: .normal, distance: .standard).rejectMultipleFaces)
}
