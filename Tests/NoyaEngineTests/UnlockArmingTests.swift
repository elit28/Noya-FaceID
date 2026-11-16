import Testing
import Foundation
@testable import NoyaEngine

private final class Clock: @unchecked Sendable {
    var t: TimeInterval = 10_000
}

@Test func disarmedUntilArmed() {
    let arming = UnlockArming(now: { 0 })
    #expect(!arming.isArmed)
    #expect(arming.remaining == nil)
}

@Test func armingExpiresAfterTheChosenDuration() {
    let clock = Clock()
    let arming = UnlockArming(now: { clock.t })
    arming.arm(hours: 8)
    #expect(arming.isArmed)
    #expect(arming.remaining == 8 * 3600)
    clock.t += 8 * 3600 - 1
    #expect(arming.isArmed)
    clock.t += 1
    #expect(!arming.isArmed)
    #expect(arming.remaining == nil)
}

@Test func repeatedUnknownFacesDisarm() {
    let arming = UnlockArming(now: { 0 })
    arming.arm(hours: 24)
    for _ in 1..<UnlockArming.rejectionsBeforeDisarm {
        #expect(arming.recordRejectedFace() == false)
    }
    #expect(arming.isArmed)
    #expect(arming.recordRejectedFace() == true)
    #expect(!arming.isArmed)
}

@Test func aSuccessfulUnlockResetsRejections() {
    let arming = UnlockArming(now: { 0 })
    arming.arm(hours: 24)
    for _ in 1..<UnlockArming.rejectionsBeforeDisarm { arming.recordRejectedFace() }
    arming.recordUnlock()
    #expect(arming.recordRejectedFace() == false)
    #expect(arming.isArmed)
}

@Test func disarmIsImmediate() {
    let arming = UnlockArming(now: { 0 })
    arming.arm(hours: 168)
    arming.disarm()
    #expect(!arming.isArmed)
}

@Test func emptyPasswordIsNeverValid() {
    #expect(LoginPasswordVerifier.verify("") == .invalid)
}
