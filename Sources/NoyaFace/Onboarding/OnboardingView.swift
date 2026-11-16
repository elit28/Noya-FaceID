import AppKit
import SwiftUI

/// Assistant de configuration (maquette validée) : Bienvenue, Fonctions, Autorisations,
/// Visage, Terminé.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, features, permissions, face, done

        var title: LocalizedStringKey {
            switch self {
            case .welcome: return "Bienvenue"
            case .features: return "Fonctions"
            case .permissions: return "Autorisations"
            case .face: return "Visage"
            case .done: return "Terminé"
            }
        }
    }

    let onFinish: () -> Void
    @State private var step: Step = .welcome
    @State private var permissions = PermissionsModel()
    @State private var enrollment = EnrollmentModel()
    @AppStorage(FeatureKeys.appProtection) private var appProtection = true
    @AppStorage(FeatureKeys.awayLock) private var awayLock = true

    var body: some View {
        VStack(spacing: 0) {
            StepIndicator(current: step)
                .padding(.top, 14)
            Group {
                switch step {
                case .welcome: WelcomeStep()
                case .features: FeaturesStep(appProtection: $appProtection, awayLock: $awayLock)
                case .permissions: PermissionsStep(permissions: permissions, needsAccessibility: awayLock)
                case .face: EnrollmentStep(model: enrollment, permissions: permissions)
                case .done: DoneStep(appProtection: appProtection, awayLock: awayLock)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 56)
            .padding(.top, 18)
            footer
                .padding(.horizontal, 56)
                .padding(.bottom, 22)
        }
        .frame(width: 820, height: 640)
        .onAppear { permissions.refresh() }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step != .welcome && step != .done && !enrollmentBusy {
                Button("Retour") { move(by: -1) }
                    .controlSize(.large)
            }
            Spacer()
            primaryButton
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch step {
        case .welcome:
            Button("Commencer") { move(by: 1) }
                .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
        case .permissions:
            Button("Continuer") { move(by: 1) }
                .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
                .disabled(!permissions.cameraGranted)
        case .face:
            Button("Continuer") { move(by: 1) }
                .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
                .disabled(enrollment.phase != .done)
        case .done:
            Button("Terminer") {
                AppModel.shared.completeOnboarding()
                onFinish()
            }
            .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
        default:
            Button("Continuer") { move(by: 1) }
                .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
        }
    }

    private var enrollmentBusy: Bool {
        guard step == .face else { return false }
        switch enrollment.phase {
        case .scanning, .saving: return true
        default: return false
        }
    }

    private func move(by offset: Int) {
        guard let next = Step(rawValue: step.rawValue + offset) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { step = next }
    }
}

// MARK: - Indicateur d'étapes

private struct StepIndicator: View {
    let current: OnboardingView.Step

    var body: some View {
        HStack(spacing: 4) {
            ForEach(OnboardingView.Step.allCases, id: \.rawValue) { step in
                Text(step.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(color(for: step))
                    .background(Capsule().fill(step == current ? Color.accentColor.opacity(0.14) : Color.clear))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func color(for step: OnboardingView.Step) -> Color {
        if step == current { return .accentColor }
        return step.rawValue < current.rawValue ? .green : .secondary
    }
}

// MARK: - Étapes

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: BrandMark.appIconImage(size: 96))
                .accessibilityHidden(true)
                .padding(.top, 12)
            Text("Bienvenue dans NOYA Face")
                .font(.largeTitle.weight(.bold))
                .padding(.top, 20)
            Text("Protégez vos applications et votre Mac avec votre visage. Tout reste sur ce Mac.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            HStack(alignment: .top, spacing: 18) {
                Feature(symbol: "lock", title: "Entièrement local", detail: "Aucune image enregistrée, aucune connexion à Internet.")
                Feature(symbol: "square.grid.2x2", title: "Applications protégées", detail: "Votre visage, puis Touch ID ou votre mot de passe.")
                Feature(symbol: "figure.walk", title: "Verrouillage auto", detail: "Le Mac se verrouille quand vous vous éloignez.")
            }
            .padding(.top, 30)
            WarningNote(text: "La caméra d’un Mac n’est pas Face ID : elle ne mesure pas la profondeur du visage. NOYA Face apporte confort et confidentialité, mais ne remplace pas un mot de passe macOS robuste.")
                .padding(.top, 26)
        }
    }

    private struct Feature: View {
        let symbol: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.12)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FeaturesStep: View {
    @Binding var appProtection: Bool
    @Binding var awayLock: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("Que souhaitez-vous activer ?")
                .font(.largeTitle.weight(.bold))
            Text("Vous pourrez tout modifier plus tard dans les réglages.")
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            VStack(spacing: 10) {
                OptionCard(isOn: $appProtection, title: "Protéger des applications",
                           detail: "Messages, Notes, Photos… masquées jusqu’à votre authentification.", badge: "Recommandé")
                OptionCard(isOn: $awayLock, title: "Verrouiller le Mac quand je m’éloigne",
                           detail: "Nécessite l’autorisation Accessibilité. La caméra ne s’allume qu’après une période d’inactivité.", badge: "Recommandé")
                OptionCard(isOn: .constant(false), title: "Déverrouiller l’écran avec mon visage",
                           detail: "Indisponible dans cette version : protéger votre mot de passe par Touch ID nécessite une version signée par un compte Apple Developer.",
                           badge: "Avancé", enabled: false)
            }
            .padding(.top, 24)
        }
    }

    private struct OptionCard: View {
        @Binding var isOn: Bool
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
        let badge: LocalizedStringKey
        var enabled = true

        var body: some View {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(enabled ? Color.green.opacity(0.15) : Color.orange.opacity(0.18)))
                    }
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                }
                .padding(.leading, 6)
            }
            .toggleStyle(.checkbox)
            .disabled(!enabled)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isOn ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1.5))
        }
    }
}

private struct PermissionsStep: View {
    let permissions: PermissionsModel
    let needsAccessibility: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("Autorisations")
                .font(.largeTitle.weight(.bold))
            Text("NOYA Face ne demande que le strict nécessaire pour les fonctions choisies.")
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Form {
                LabeledContent {
                    if permissions.cameraGranted {
                        StatusBadge(text: "Autorisée", positive: true)
                    } else if permissions.cameraDenied {
                        Button("Ouvrir Réglages Système") { openSettings(SystemKeys.cameraSettingsURL) }
                    } else {
                        Button("Autoriser") { Task { await permissions.requestCamera() } }
                            .buttonStyle(.borderedProminent)
                    }
                } label: {
                    Text("Caméra (obligatoire)")
                    Text(cameraDetail)
                }
                if needsAccessibility {
                    LabeledContent {
                        if permissions.accessibilityGranted {
                            StatusBadge(text: "Accordée", positive: true)
                        } else {
                            Button("Ouvrir Réglages Système") { permissions.requestAccessibility() }
                        }
                    } label: {
                        Text("Accessibilité")
                        Text("Pour verrouiller le Mac avec le raccourci système quand vous vous éloignez.")
                    }
                }
                LabeledContent {
                    Toggle("Ouvrir à l’ouverture de session", isOn: Binding(
                        get: { permissions.openAtLogin },
                        set: { permissions.setOpenAtLogin($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                } label: {
                    Text("Ouvrir à l’ouverture de session")
                    Text(loginItemDetail)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(height: needsAccessibility ? 270 : 200)
            Text("Vous pouvez retirer ces autorisations à tout moment dans Réglages Système. Les fonctions concernées se désactivent alors proprement.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .onAppear { permissions.refresh() }
    }

    private var cameraDetail: LocalizedStringKey {
        if permissions.cameraDenied {
            return "Refusée : autorisez NOYA Face dans Réglages Système › Confidentialité et sécurité › Caméra."
        }
        return "Pour reconnaître votre visage. Les images sont analysées en mémoire, jamais enregistrées."
    }

    private var loginItemDetail: LocalizedStringKey {
        if permissions.loginItemNeedsApproval {
            return "À approuver dans Réglages Système › Général › Ouverture."
        }
        return "Pour que la protection soit active dès la connexion."
    }

    private func openSettings(_ address: String) {
        if let url = URL(string: address) { NSWorkspace.shared.open(url) }
    }
}

private struct DoneStep: View {
    let appProtection: Bool
    let awayLock: Bool

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .padding(.top, 12)
                .accessibilityHidden(true)
            Text("NOYA Face est prêt")
                .font(.largeTitle.weight(.bold))
                .padding(.top, 16)
            Text("L’application reste discrète dans la barre des menus.")
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Form {
                LabeledContent("Mon visage") { StatusBadge(text: "Enregistré · 2 scans", positive: true) }
                LabeledContent("Applications protégées") {
                    StatusBadge(text: appProtection ? "Arrive dans une prochaine version" : "Désactivé", positive: false)
                }
                LabeledContent("Verrouillage quand vous vous éloignez") {
                    StatusBadge(text: awayLock ? "Arrive dans une prochaine version" : "Désactivé", positive: false)
                }
                LabeledContent("Déverrouillage de l’écran") { StatusBadge(text: "Indisponible (version non signée)", positive: false) }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(height: 230)
        }
    }
}

// MARK: - Éléments communs

struct StatusBadge: View {
    let text: LocalizedStringKey
    let positive: Bool

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9).padding(.vertical, 3)
            .foregroundStyle(positive ? Color.green : Color.secondary)
            .background(Capsule().fill(positive ? Color.green.opacity(0.14) : Color.secondary.opacity(0.12)))
    }
}

struct WarningNote: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(text).font(.callout)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
    }
}
