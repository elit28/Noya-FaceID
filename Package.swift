// swift-tools-version:6.0
import PackageDescription

// NOYA Face — paquet Swift.
// NoyaCore et NoyaEngine proviennent de HeyMac (MIT, commit a73667d) : voir THIRD_PARTY_NOTICES.md.
let package = Package(
    name: "NoyaFace",
    defaultLocalization: "fr",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NoyaFace", targets: ["NoyaFace"]),
    ],
    targets: [
        // Reconnaissance, présence réelle, stockage chiffré, état du verrouillage (Swift 6 strict).
        .target(
            name: "NoyaCore",
            resources: [
                .copy("Resources/AntiSpoof.mlpkgdata"),
                .copy("Resources/FaceRecognition.mlpkgdata"),
            ]
        ),
        // Moteur : caméra, enrôlement, vérification, protection d'applications (Swift 6 strict).
        .target(
            name: "NoyaEngine",
            dependencies: ["NoyaCore"]
        ),
        // Application (barre des menus, réglages) — Swift 6 strict.
        .executableTarget(
            name: "NoyaFace",
            dependencies: ["NoyaCore"]
        ),
        .testTarget(
            name: "NoyaCoreTests",
            dependencies: ["NoyaCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "NoyaEngineTests",
            dependencies: ["NoyaEngine", "NoyaCore"]
        ),
    ]
)
