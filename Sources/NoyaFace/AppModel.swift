import Foundation
import NoyaEngine
import Observation

/// État partagé de l'application : réglages du moteur et chargement du moteur de
/// reconnaissance (modèles Core ML), fait à la demande hors du fil principal.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    enum RuntimeState {
        case idle
        case loading
        case ready(NoyaRuntime)
        case failed(String)
    }

    let settings = EngineSettings()
    private(set) var runtimeState: RuntimeState = .idle

    private init() {}

    var runtime: NoyaRuntime? {
        if case .ready(let runtime) = runtimeState { return runtime }
        return nil
    }

    var onboardingComplete: Bool {
        settings.onboardingComplete
    }

    /// Charge le moteur une seule fois (compilation des modèles : quelques instants).
    func loadRuntime() async -> NoyaRuntime? {
        if let runtime { return runtime }
        if case .loading = runtimeState {
            while case .loading = runtimeState {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            return runtime
        }
        runtimeState = .loading
        let result = await Task.detached(priority: .userInitiated) { () -> Result<NoyaRuntime, Error> in
            Result { try NoyaRuntime() }
        }.value
        switch result {
        case .success(let runtime):
            runtimeState = .ready(runtime)
            return runtime
        case .failure(let error):
            runtimeState = .failed(String(describing: error))
            return nil
        }
    }

    func completeOnboarding() {
        settings.setupComplete = true
        settings.onboardingComplete = true
    }
}
