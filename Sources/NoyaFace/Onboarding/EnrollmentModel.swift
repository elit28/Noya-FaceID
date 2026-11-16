import Foundation
import NoyaCore
import NoyaEngine
import Observation

/// Pilote l'enregistrement du visage en deux tours (« tournez la tête »).
@MainActor
@Observable
final class EnrollmentModel {
    enum Phase: Equatable {
        case loading
        case ready
        case scanning(index: Int)
        case betweenScans
        case saving
        case done
        case failed(FailureReason)
    }

    enum FailureReason: Equatable {
        case engineUnavailable
        case cameraUnavailable
        case cameraBusy
        case timedOut
        case saveFailed
    }

    static let sectorCount = 12

    private(set) var phase: Phase = .loading
    private(set) var filled = [Bool](repeating: false, count: sectorCount)
    private(set) var direction: Double?
    private(set) var issue: GuidedEnrollmentIssue?
    private(set) var calibrating = false
    /// Option d'accessibilité : un demi-cercle suffit, avec des mouvements de tête plus petits.
    private(set) var partialCircle = false

    private var scans: [[FaceEmbedding]] = []
    private var runtime: NoyaRuntime?
    private var enroller: GuidedEnroller?
    private let cancelFlag = CancelFlag()

    var filledCount: Int { filled.filter { $0 }.count }

    func prepare() async {
        guard phase == .loading else { return }
        guard let runtime = await AppModel.shared.loadRuntime() else {
            phase = .failed(.engineUnavailable)
            return
        }
        self.runtime = runtime
        makeEnroller()
        phase = .ready
    }

    /// Modifiable seulement avant le premier tour : les deux tours suivent la même consigne.
    func setPartialCircle(_ enabled: Bool) {
        guard phase == .ready, scans.isEmpty else { return }
        partialCircle = enabled
        makeEnroller()
    }

    private func makeEnroller() {
        enroller = runtime?.guidedEnroller(config: partialCircle ? .partialCircle : GuidedEnrollmentConfig())
    }

    /// Lance le tour suivant (le premier, puis le second après la pause).
    func startScan() {
        guard let enroller else { return }
        let index = scans.count
        filled = [Bool](repeating: false, count: Self.sectorCount)
        direction = nil
        issue = nil
        calibrating = true
        phase = .scanning(index: index)
        cancelFlag.reset()
        let flag = cancelFlag
        // Le tour s'arrête de lui-même (cercle complet, délai dépassé ou annulation).
        Task.detached(priority: .userInitiated) { [self] in
            let result = Result<[FaceEmbedding], Error> {
                try enroller.runScan(shouldContinue: { !flag.isSet }) { event in
                    Task { @MainActor in self.apply(event) }
                }
            }
            await self.finishScan(result)
        }
    }

    func cancel() {
        cancelFlag.set()
    }

    private func apply(_ event: GuidedEnrollmentEvent) {
        // Un événement tardif ne doit pas effacer l'état final d'un tour terminé.
        guard case .scanning = phase else { return }
        switch event {
        case .calibrating:
            calibrating = true
        case .progress(let filled, let direction):
            calibrating = false
            self.filled = filled
            self.direction = direction
            issue = nil
        case .issue(let issue):
            self.issue = issue
        }
    }

    private func finishScan(_ result: Result<[FaceEmbedding], Error>) async {
        switch result {
        case .success(let embeddings):
            filled = [Bool](repeating: true, count: Self.sectorCount)
            direction = nil
            issue = nil
            scans.append(embeddings)
            if scans.count < 2 {
                phase = .betweenScans
            } else {
                await save()
            }
        case .failure(GuidedEnrollmentError.cancelled):
            phase = .ready
        case .failure(GuidedEnrollmentError.cameraBusy):
            phase = .failed(.cameraBusy)
        case .failure(GuidedEnrollmentError.cameraUnavailable):
            phase = .failed(.cameraUnavailable)
        case .failure:
            phase = .failed(.timedOut)
        }
    }

    private func save() async {
        guard let enroller else { return }
        phase = .saving
        let scans = self.scans
        let saved = await Task.detached(priority: .userInitiated) {
            (try? enroller.saveEnrollment(scans: scans)) != nil
        }.value
        phase = saved ? .done : .failed(.saveFailed)
    }

    /// Recommence depuis le premier tour (après un échec).
    func restart() {
        scans = []
        filled = [Bool](repeating: false, count: Self.sectorCount)
        direction = nil
        issue = nil
        if enroller == nil {
            // Le moteur n'avait pas démarré : nouvelle tentative de chargement.
            phase = .loading
            Task { await prepare() }
        } else {
            phase = .ready
        }
    }
}

/// Drapeau d'annulation partagé avec la tâche d'arrière-plan.
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool { lock.withLock { value } }
    func set() { lock.withLock { value = true } }
    func reset() { lock.withLock { value = false } }
}
