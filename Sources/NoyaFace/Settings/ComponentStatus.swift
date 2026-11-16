import AppKit
import AVFoundation
import NoyaCore
import Observation

/// État réel des composants, affiché dans les réglages. Aucune autorisation n'est demandée ici :
/// la caméra n'est jamais allumée, seul son statut d'autorisation est lu.
@MainActor
@Observable
final class ComponentStatus {
    enum ModelState: Equatable {
        case checking
        case loaded
        case missing
    }

    private(set) var cameraAuthorization: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    private(set) var hasNotch = false
    private(set) var livenessModel: ModelState = .checking
    private(set) var recognitionModel: ModelState = .checking

    func refresh() async {
        cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
        hasNotch = NSScreen.screens.contains { $0.safeAreaInsets.top > 0 }
        livenessModel = .checking
        recognitionModel = .checking

        // Le chargement d'un modèle Core ML peut prendre un moment : hors du fil principal.
        let (livenessLoaded, recognitionLoaded) = await Task.detached(priority: .utility) {
            ((try? AntiSpoofClassifier()) != nil, (try? FaceEmbedder()) != nil)
        }.value

        livenessModel = livenessLoaded ? .loaded : .missing
        recognitionModel = recognitionLoaded ? .loaded : .missing
    }
}
