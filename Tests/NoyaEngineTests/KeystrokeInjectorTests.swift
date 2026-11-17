import Testing
@testable import NoyaEngine

@Test func theFieldIsClearedBeforeThePasswordIsTyped() {
    let presses = KeystrokeInjector.presses(for: "ab")
    #expect(presses.count == KeystrokeInjector.clearingPresses + 3)
    #expect(presses.prefix(KeystrokeInjector.clearingPresses).allSatisfy { $0.virtualKey == 0x33 && $0.unicode == nil })
    #expect(presses[KeystrokeInjector.clearingPresses].unicode == Array("a".utf16))
    #expect(presses[KeystrokeInjector.clearingPresses + 1].unicode == Array("b".utf16))
    #expect(presses.last?.virtualKey == 0x24)
    #expect(presses.last?.waitAfterRelease == false)
}
