import Foundation
import Testing
@testable import NoyaEngine

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("update-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func namesMatchThePublicationWorkflow() {
    #expect(UpdatePackage.archiveName(version: "1.0.3") == "NOYA-Face-1.0.3.zip")
    #expect(UpdatePackage.checksumName(version: "1.0.3") == "NOYA-Face-1.0.3.sha256")
}

@Test func parsesShasumOutput() {
    let text = """
    980fe75db759bf44ee5b67675a3fe328058e928f90249bae8de0cf0a95a1f58e  NOYA-Face-1.0.0.dmg
    80D862C2B4BE7B0E1D52E17CCC2E04C93BAB3D1082866D0DB2D293859EDED05F *NOYA-Face-1.0.0.zip
    pas une empreinte  autre.txt
    """
    let sums = UpdatePackage.parseChecksums(text)
    #expect(sums.count == 2)
    #expect(sums["NOYA-Face-1.0.0.zip"] == "80d862c2b4be7b0e1d52e17ccc2e04c93bab3d1082866d0db2d293859eded05f")
}

@Test func checksumIsVerifiedAgainstTheFile() throws {
    let dir = try temporaryDirectory()
    let file = dir.appendingPathComponent("NOYA-Face-9.9.9.zip")
    try Data("NOYA".utf8).write(to: file)
    // SHA-256 de « NOYA ».
    let good = try UpdatePackage.sha256Hex(of: file)
    #expect(good.count == 64)
    try UpdatePackage.verifyChecksum(of: file, named: file.lastPathComponent, checksums: [file.lastPathComponent: good])
    #expect(throws: UpdateError.checksumMismatch) {
        try UpdatePackage.verifyChecksum(of: file, named: file.lastPathComponent,
                                         checksums: [file.lastPathComponent: String(repeating: "0", count: 64)])
    }
    #expect(throws: UpdateError.checksumMissing) {
        try UpdatePackage.verifyChecksum(of: file, named: file.lastPathComponent, checksums: [:])
    }
}

@Test func onlyNoyaFaceInTheAnnouncedVersionIsAccepted() throws {
    let dir = try temporaryDirectory()
    let app = dir.appendingPathComponent("NOYA Face.app")
    try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
    func write(_ plist: [String: Any]) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: app.appendingPathComponent("Contents/Info.plist"))
    }

    try write(["CFBundleIdentifier": "fr.noya360.noyaface", "CFBundleShortVersionString": "1.0.3"])
    try UpdatePackage.validateBundle(at: app, bundleID: "fr.noya360.noyaface", version: "1.0.3")
    #expect(throws: UpdateError.wrongVersion) {
        try UpdatePackage.validateBundle(at: app, bundleID: "fr.noya360.noyaface", version: "1.0.4")
    }
    try write(["CFBundleIdentifier": "com.example.autre", "CFBundleShortVersionString": "1.0.3"])
    #expect(throws: UpdateError.wrongBundle) {
        try UpdatePackage.validateBundle(at: app, bundleID: "fr.noya360.noyaface", version: "1.0.3")
    }
}
