import Testing
@testable import NoyaEngine

@Test func readsTagsWithPrefixAndSuffix() {
    #expect(AppVersion.components("v1.2.3") == [1, 2, 3])
    #expect(AppVersion.components("0.9.0-beta") == [0, 9, 0])
    #expect(AppVersion.components("1.0") == [1, 0])
    #expect(AppVersion.components("version un") == nil)
    #expect(AppVersion.components("1..2") == nil)
}

@Test func comparesNumericallyNotAlphabetically() {
    #expect(AppVersion.isNewer("v1.10.0", than: "1.9.9"))
    #expect(AppVersion.isNewer("1.0.1", than: "1.0"))
    #expect(!AppVersion.isNewer("1.0", than: "1.0.0"))
    #expect(!AppVersion.isNewer("0.9.0", than: "1.0.0"))
}

@Test func unreadableVersionsAreNeverNewer() {
    #expect(!AppVersion.isNewer("latest", than: "1.0.0"))
    #expect(!AppVersion.isNewer("2.0.0", than: "dev"))
}
