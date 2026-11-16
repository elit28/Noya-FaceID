import Foundation
import Testing
@testable import NoyaCore

/// Garde-fou de licence : aucun poids InsightFace/ArcFace ne doit être redistribué.
@Test func arcFaceModelIsNeverBundled() {
    #expect(ModelResources.url(named: "ArcFace") == nil, "ArcFace (licence non commerciale) ne doit jamais être embarqué")
}

@Test func antiSpoofModelResourceExists() {
    let url = ModelResources.url(named: "AntiSpoof")
    #expect(url != nil, "AntiSpoof.mlpkgdata should be bundled as a resource")
}

@Test func modelBundleIsFoundInAppResourcesDirectory() throws {
    let resources = makeTempDirectory()
    let model = resources.appendingPathComponent("\(ModelResources.bundleName)/Contents/Resources/Probe.mlpkgdata")
    try FileManager.default.createDirectory(at: model, withIntermediateDirectories: true)
    let bundle = ModelResources.resourceBundle(searching: [resources])
    #expect(bundle.url(forResource: "Probe", withExtension: "mlpkgdata")?.resolvingSymlinksInPath().path.hasPrefix(resources.resolvingSymlinksInPath().path) == true)
}
