import NoyaCore
import NoyaEngine
import SwiftUI

/// Tableau de bord : état de la protection, actions rapides, résumé et activité récente.
struct DashboardPage: View {
    let navigate: (SettingsPage) -> Void

    @State private var unlock = ScreenUnlockController.shared
    @State private var activity = ActivityLog.shared
    @State private var updates = UpdateChecker.shared
    @State private var hasFace: Bool?
    @State private var test: TestState = .idle
    @AppStorage(FeatureKeys.appProtection) private var appProtection = false
    @AppStorage(FeatureKeys.awayLock) private var awayLock = false
    @AppStorage(AwayLockKeys.idleMinutes) private var idleMinutes = 2

    enum TestState: Equatable {
        case idle
        case running
        case matched(score: Int)
        case notMatched(score: Int?)
        case unavailable
    }

    var body: some View {
        Form {
            if case .available(let version) = updates.state {
                Section {
                    LabeledContent {
                        HStack {
                            Button("Nouveautés") { updates.openReleasePage() }
                            Button("Mettre à jour") { Task { await updates.installUpdate() } }
                                .buttonStyle(.borderedProminent)
                        }
                    } label: {
                        Text("Mise à jour")
                        Text("La version \(version) de NOYA Face est disponible.")
                    }
                }
            }
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: BrandMark.appIconImage(size: 52))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("État de la protection sur ce Mac. Tout est traité localement.")
                            .foregroundStyle(.secondary)
                        Text(protectionLine)
                            .font(.headline)
                    }
                    Spacer()
                    StatusBadge(text: isProtecting ? "Protection active" : "Protection inactive", positive: isProtecting)
                }
                HStack {
                    Button("Verrouiller maintenant") { lockNow() }
                    Button {
                        Task { await runTest() }
                    } label: {
                        Text(testTitle)
                    }
                    .disabled(test == .running || hasFace != true)
                    if let result = testResult {
                        Text(result)
                            .foregroundStyle(testMatched ? Color.green : Color.orange)
                    }
                }
            }

            Section("Résumé") {
                SummaryRow(title: "Mon visage", value: Text(faceValue), action: "Gérer") { navigate(.face) }
                SummaryRow(title: "Applications protégées", value: appsValue, action: "Gérer") { navigate(.apps) }
                SummaryRow(title: "Recherche du visage", value: Text(scanValue), action: "Régler") { navigate(.security) }
                SummaryRow(title: "Verrouillage en cas d’absence", value: Text(awayValue), action: "Régler") { navigate(.security) }
                SummaryRow(title: "Déverrouillage de l’écran", value: Text(unlockValue), action: "Régler") { navigate(.security) }
            }

            Section("Activité récente") {
                if activity.entries.isEmpty {
                    Text("Aucune activité depuis le lancement de NOYA Face.")
                        .foregroundStyle(.secondary)
                }
                ForEach(activity.entries) { entry in
                    HStack {
                        StatusBadge(text: label(for: entry.kind), positive: entry.kind == .success)
                        Text(entry.text)
                        Spacer()
                        Text(entry.date, style: .time)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                WarningNote(text: "La caméra du Mac voit une image en deux dimensions : NOYA Face n’offre pas le niveau de sécurité de Face ID. Conservez un mot de passe macOS robuste.")
            }
        }
        .formStyle(.grouped)
        .task {
            if let runtime = await AppModel.shared.loadRuntime() {
                hasFace = runtime.hasFaceProfile
            } else {
                hasFace = false
            }
            await unlock.refresh()
        }
    }

    private var isProtecting: Bool {
        AppLockController.shared.isRunning || awayLock || unlock.armedUntil != nil
    }

    private var protectionLine: LocalizedStringKey {
        let apps = AppLockController.shared.store.apps.count
        guard appProtection else { return "Protection des applications désactivée" }
        return apps > 1 ? "\(apps) applications protégées" : "\(apps) application protégée"
    }

    private var scanValue: LocalizedStringKey {
        let seconds = AppModel.shared.settings.scanSeconds
        return "\(seconds) s maximum"
    }

    private var faceValue: LocalizedStringKey {
        switch hasFace {
        case .some(true): return "Enregistré"
        case .some(false): return "Aucun visage enregistré"
        case .none: return "Vérification…"
        }
    }

    private var appsValue: Text {
        guard appProtection else { return Text("Désactivé") }
        let names = AppLockController.shared.store.apps.map(\.name)
        if names.isEmpty { return Text("Aucune application choisie") }
        let list = names.prefix(3).joined(separator: ", ") // noloc
        return Text(verbatim: names.count > 3 ? list + "…" : list) // noloc
    }

    private var awayValue: LocalizedStringKey {
        awayLock ? "Après \(idleMinutes) min d’absence" : "Désactivé"
    }

    private var unlockValue: LocalizedStringKey {
        guard unlock.isEnabled else { return "Désactivé" }
        return unlock.armedUntil == nil ? "Activé · désarmé" : "Activé · armé"
    }

    private var testTitle: LocalizedStringKey {
        test == .running ? "Recherche…" : "Tester la reconnaissance"
    }

    private var testMatched: Bool {
        if case .matched = test { return true }
        return false
    }

    private var testResult: LocalizedStringKey? {
        switch test {
        case .idle, .running: return nil
        case .matched(let score): return "Visage reconnu · qualité \(score)/100"
        case .notMatched(let score?): return "Visage non reconnu · qualité \(score)/100"
        case .notMatched(nil): return "Visage non reconnu"
        case .unavailable: return "Reconnaissance indisponible"
        }
    }

    private func label(for kind: ActivityLog.Kind) -> LocalizedStringKey {
        switch kind {
        case .success: return "Réussi"
        case .refused: return "Refusé"
        case .locked: return "Verrouillé"
        }
    }

    private func lockNow() {
        if ScreenLocker.canLock {
            try? ScreenLocker.lock()
        } else {
            PermissionsModel().requestAccessibility()
        }
    }

    private func runTest() async {
        guard let runtime = await AppModel.shared.loadRuntime() else {
            test = .unavailable
            return
        }
        test = .running
        IslandController.shared.show(.searching)
        let settings = AppModel.shared.settings
        let matcher = runtime.verifier(interactive: true, strictness: settings.strictness, distance: settings.detectionDistance)
        let seconds = TimeInterval(settings.scanSeconds)
        let outcome = await Task.detached(priority: .userInitiated) {
            matcher.run(timeout: seconds, requiredConsecutive: 2, waitForTurn: 0.5, keepGoing: { true })
        }.value
        // Note calculée seulement si un visage a été analysé.
        let score: Int? = outcome.framesEvaluated > 0
            ? ScanQuality.verificationScore(similarity: outcome.bestSimilarity, threshold: settings.strictness.threshold,
                                            liveness: outcome.bestLiveness, livenessThreshold: PipelineConfig().livenessThreshold)
            : nil
        if outcome.matched {
            test = .matched(score: score ?? 0)
            IslandController.shared.flash(.success)
        } else if outcome.failure != nil {
            test = .unavailable
            IslandController.shared.hide()
        } else {
            test = .notMatched(score: score)
            IslandController.shared.flash(.refused, seconds: 1.6)
        }
    }
}

private struct SummaryRow: View {
    let title: LocalizedStringKey
    let value: Text
    let action: LocalizedStringKey
    let perform: () -> Void

    var body: some View {
        LabeledContent {
            HStack {
                value.foregroundStyle(.secondary)
                Button(action, action: perform)
            }
        } label: {
            Text(title)
        }
    }
}
