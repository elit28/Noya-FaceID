import NoyaEngine
import SwiftUI

/// Réglages « Déverrouillage de l'écran » (maquette Main validée, page Sécurité, mode avancé).
struct ScreenUnlockSection: View {
    @State private var controller = ScreenUnlockController.shared
    @State private var permissions = PermissionsModel()
    @State private var enabled = AppModel.shared.settings.lockScreenEnabled
    @State private var setup: UnlockSetupView.Start?
    @AppStorage(ScreenUnlockKeys.armHours) private var armHours = UnlockArming.defaultHours

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { enabled }, set: { isOn in toggle(isOn) })) {
                Text("Déverrouiller l’écran avec mon visage")
                Text("NOYA Face tape votre mot de passe macOS à votre place quand votre visage est reconnu. Désactivé par défaut.")
            }
            if enabled {
                Text("Sur l’écran verrouillé, bougez la souris, touchez le trackpad ou appuyez sur Maj : la reconnaissance se lance, avec 2 essais à chaque fois.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if controller.passwordRejected {
                    WarningNote(text: "Le mot de passe enregistré a été refusé par macOS (changé depuis ?). Saisissez-le de nouveau.")
                }
                if controller.disarmedAfterRejections {
                    WarningNote(text: "Plusieurs visages inconnus ont été vus sur l’écran verrouillé : la saisie automatique a été désarmée.")
                }
                LabeledContent {
                    if controller.hasPassword {
                        HStack {
                            StatusBadge(text: "Enregistré", positive: true)
                            Button("Modifier…") { setup = .password }
                        }
                    } else {
                        Button("Saisir…") { setup = .password }
                    }
                } label: {
                    Text("Mot de passe macOS")
                    Text("Vérifié par macOS avant d’être enregistré, puis chiffré sur ce Mac.")
                }
                LabeledContent {
                    if let until = controller.armedUntil {
                        HStack {
                            StatusBadge(text: armedLabel(until), positive: true)
                            Button("Désarmer") { controller.disarm() }
                        }
                    } else {
                        Button("Armer avec Touch ID") { Task { await controller.arm() } }
                            .disabled(!controller.hasPassword)
                    }
                } label: {
                    Text("Saisie automatique")
                    Text("Désarmée à chaque redémarrage et à chaque relance de NOYA Face.")
                }
                Picker(selection: $armHours) {
                    ForEach(UnlockArming.durationChoices, id: \.self) { hours in
                        Text(durationLabel(hours)).tag(hours)
                    }
                } label: {
                    Text("Durée d’armement")
                    Text("Ensuite, Touch ID ou votre mot de passe est demandé pour réarmer.")
                }
                LabeledContent {
                    Text(verbatim: "2")
                } label: {
                    Text("Tentatives par verrouillage")
                    Text("Au-delà, saisissez votre mot de passe. Après plusieurs visages inconnus, la saisie automatique est désarmée.")
                }
                LabeledContent {
                    if permissions.accessibilityGranted {
                        StatusBadge(text: "Accordée", positive: true)
                    } else {
                        Button("Ouvrir Réglages Système") { permissions.requestAccessibility() }
                    }
                } label: {
                    Text("Accessibilité")
                    Text("Nécessaire pour taper le mot de passe sur l’écran verrouillé.")
                }
            }
        } header: {
            HStack(spacing: 8) {
                Text("Déverrouillage de l’écran")
                StatusBadge(text: "Avancé", positive: false)
            }
        }
        .sheet(item: $setup) { start in
            UnlockSetupView(start: start) { saved in
                setup = nil
                guard saved else { return }
                Task { await finishSetup() }
            }
        }
        .onAppear { permissions.refresh() }
        .task { await controller.refresh() }
    }

    private func toggle(_ isOn: Bool) {
        if isOn {
            setup = .disclosure
        } else {
            enabled = false
            Task { await controller.disable() }
        }
    }

    private func finishSetup() async {
        enabled = true
        await controller.enable()
        if !permissions.accessibilityGranted { permissions.requestAccessibility() }
        if controller.armedUntil == nil { await controller.arm() }
    }

    private func armedLabel(_ date: Date) -> LocalizedStringKey {
        let until = date.formatted(date: .abbreviated, time: .shortened)
        return "Armée jusqu’au \(until)"
    }

    private func durationLabel(_ hours: Int) -> LocalizedStringKey {
        hours < 48 ? "\(hours) h" : "\(hours / 24) jours"
    }
}

/// Mise en place : avertissements honnêtes, puis saisie du mot de passe vérifié par macOS.
struct UnlockSetupView: View {
    enum Start: String, Identifiable {
        case disclosure
        case password
        var id: String { rawValue }
    }

    let start: Start
    let onFinish: (Bool) -> Void
    @State private var step: Start = .disclosure
    @State private var password = ""
    @State private var verifying = false
    @State private var error: LocalizedStringKey?

    init(start: Start, onFinish: @escaping (Bool) -> Void) {
        self.start = start
        self.onFinish = onFinish
        _step = State(initialValue: start)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch step {
            case .disclosure: disclosure
            case .password: passwordEntry
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private var disclosure: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Avant d’activer")
                .font(.title2.weight(.bold))
            Bullet(symbol: "lock", text: "Votre mot de passe macOS est vérifié par macOS, puis stocké chiffré (AES-256) sur ce Mac. La clé est dans votre trousseau, réservée à NOYA Face.")
            Bullet(symbol: "touchid", text: "Sans compte Apple Developer, le trousseau ne peut pas exiger Touch ID pour lire ce mot de passe. NOYA Face exige donc Touch ID ou votre mot de passe pour armer la saisie automatique, pour une durée limitée.")
            Bullet(symbol: "video", text: "Une webcam n’est pas Face ID : une vidéo de vous pourrait tromper la détection de présence réelle.")
            Bullet(symbol: "power", text: "Le mot de passe reste obligatoire après un redémarrage, pour FileVault et au changement d’utilisateur.")
            Bullet(symbol: "accessibility", text: "L’autorisation Accessibilité est nécessaire pour taper le mot de passe.")
            HStack {
                Spacer()
                Button("Annuler") { onFinish(false) }
                    .keyboardShortcut(.cancelAction)
                Button("Je comprends, continuer") { step = .password }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 6)
        }
    }

    private var passwordEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mot de passe macOS")
                .font(.title2.weight(.bold))
            Text("Celui de votre session, vérifié par macOS avant d’être enregistré. Il n’est jamais affiché ni envoyé.")
                .foregroundStyle(.secondary)
            SecureField("Mot de passe", text: $password)
                .textFieldStyle(.roundedBorder)
                .disabled(verifying)
                .onSubmit { save() }
            if let error {
                Text(error)
                    .foregroundStyle(.red)
            }
            HStack {
                if verifying { ProgressView().controlSize(.small) }
                Spacer()
                Button("Annuler") { onFinish(false) }
                    .keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty || verifying)
            }
        }
    }

    private func save() {
        guard !password.isEmpty, !verifying else { return }
        verifying = true
        error = nil
        let candidate = password
        Task {
            let result = await ScreenUnlockController.shared.savePassword(candidate)
            verifying = false
            switch result {
            case .saved:
                password = ""
                onFinish(true)
            case .invalid:
                error = "Mot de passe incorrect."
            case .unavailable:
                error = "macOS n’a pas pu vérifier le mot de passe. Réessayez."
            case .failed:
                error = "L’enregistrement a échoué. Réessayez."
            }
        }
    }

    private struct Bullet: View {
        let symbol: String
        let text: LocalizedStringKey

        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
