import Testing
@testable import NoyaCore
@testable import NoyaEngine

@Test func identicalEmbeddingsAreFullyConsistent() throws {
    let embedding = FaceEmbedding(vector: [0.2, 0.4, 0.6, 0.8])
    let value = try #require(ScanQuality.consistency(of: [embedding, embedding, embedding]))
    #expect(abs(value - 1) < 0.0001)
    #expect(ScanQuality.consistency(of: []) == nil)
}

@Test func spreadEmbeddingsAreLessConsistent() throws {
    let a = FaceEmbedding(vector: [1, 0, 0])
    let b = FaceEmbedding(vector: [0, 1, 0])
    let value = try #require(ScanQuality.consistency(of: [a, b]))
    #expect(abs(value - 0.7071) < 0.001)
}

@Test func enrollmentScoreFollowsTheMarginAboveTheThreshold() {
    #expect(ScanQuality.enrollmentScore(consistency: 0.72, threshold: 0.42) == 100)
    #expect(ScanQuality.enrollmentScore(consistency: 0.57, threshold: 0.42) == 50)
    #expect(ScanQuality.enrollmentScore(consistency: 0.40, threshold: 0.42) == 0)
    #expect(ScanQuality.enrollmentScore(consistency: 0.99, threshold: 0.42) == 100)
}

@Test func verificationScoreWeighsMatchAndLiveness() {
    #expect(ScanQuality.verificationScore(similarity: 0.72, threshold: 0.42, liveness: 0.95, livenessThreshold: 0.6) == 100)
    #expect(ScanQuality.verificationScore(similarity: 0.42, threshold: 0.42, liveness: 0.6, livenessThreshold: 0.6) == 0)
    #expect(ScanQuality.verificationScore(similarity: 0.72, threshold: 0.42, liveness: 0.6, livenessThreshold: 0.6) == 75)
}

@Test func gradesHaveClearBoundaries() {
    #expect(ScanQuality.grade(100) == .excellent)
    #expect(ScanQuality.grade(80) == .excellent)
    #expect(ScanQuality.grade(79) == .good)
    #expect(ScanQuality.grade(60) == .good)
    #expect(ScanQuality.grade(59) == .fair)
    #expect(ScanQuality.grade(40) == .fair)
    #expect(ScanQuality.grade(39) == .poor)
}
