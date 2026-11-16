import NoyaCore
import NoyaEngine
import SwiftUI

/// Mon visage : un seul visage par Mac, avec ses apparences (lunettes, barbe, éclairage).
struct FacePage: View {
    @State private var profile: FaceProfile?
    @State private var loading = true
    @State private var loadFailed = false
    @State private var addingAppearance = false
    @State private var confirmingDeletion = false
    @State private var deletionFailed = false

    var body: some View {
        Form {
            Section {
                Text("Un seul visage par Mac : le vôtre. Vous pouvez ajouter des apparences (lunettes, barbe, éclairage) ; chacune doit correspondre à votre visage déjà enregistré. Aucune photo n’est conservée.")
                    .foregroundStyle(.secondary)
            }

            Section("Apparences enregistrées") {
                if loading {
                    ProgressView().controlSize(.small)
                } else if let profile {
                    ForEach(profile.appearances) { appearance in
                        LabeledContent {
                            Text(appearance.createdAt, format: .dateTime.day().month().year())
                                .foregroundStyle(.secondary)
                        } label: {
                            Text(verbatim: appearance.name)
                        }
                    }
                } else {
                    Text(emptyText)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button(enrollTitle) {
                        OnboardingWindowController.shared.showEnrollment()
                    }
                    Button("Ajouter une apparence") { addingAppearance = true }
                        .disabled(profile == nil)
                }
                Text("Une apparence est refusée si elle ne correspond pas à votre visage : impossible d’enregistrer une autre personne.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Stockage") {
                LabeledContent {
                    StatusBadge(text: "Chiffré", positive: true)
                } label: {
                    Text("Empreintes chiffrées sur ce Mac")
                    Text("AES-256-GCM, dans ~/Library/Application Support/NOYA Face. Clé conservée dans le trousseau.")
                }
                LabeledContent {
                    StatusBadge(text: "Jamais enregistrées", positive: true)
                } label: {
                    Text("Images de la caméra")
                    Text("Analysées en mémoire puis effacées immédiatement.")
                }
            }

            Section("Suppression") {
                LabeledContent {
                    Button("Supprimer…", role: .destructive) { confirmingDeletion = true }
                        .disabled(profile == nil)
                } label: {
                    Text("Supprimer toutes les données faciales")
                    Text("Efface le visage, ses apparences, le mot de passe enregistré et la clé de chiffrement. Confirmation par Touch ID ou mot de passe macOS.")
                }
                if deletionFailed {
                    Text("La suppression a échoué ou a été annulée.")
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .task { await load() }
        .sheet(isPresented: $addingAppearance) {
            AppearanceEnrollmentView { added in
                addingAppearance = false
                if added { Task { await load() } }
            }
        }
        .confirmationDialog("Supprimer toutes les données faciales ?", isPresented: $confirmingDeletion) {
            Button("Supprimer définitivement", role: .destructive) { Task { await deleteAll() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Action définitive. Les applications protégées demanderont Touch ID ou votre mot de passe.")
        }
    }

    private var emptyText: LocalizedStringKey {
        loadFailed ? "Impossible de lire le visage enregistré (trousseau refusé ?)." : "Aucun visage enregistré."
    }

    private var enrollTitle: LocalizedStringKey {
        profile == nil ? "Enregistrer mon visage" : "Réenregistrer"
    }

    private func load() async {
        loading = true
        defer { loading = false }
        guard let runtime = await AppModel.shared.loadRuntime(), runtime.hasFaceProfile else {
            profile = nil
            loadFailed = false
            return
        }
        let loaded = await Task.detached(priority: .userInitiated) {
            try? runtime.pipeline(interactive: true, strictness: .normal).loadProfile()
        }.value
        profile = loaded
        loadFailed = loaded == nil
    }

    private func deleteAll() async {
        deletionFailed = false
        let reason = String(localized: "supprimer vos données faciales")
        guard await LocalSystemAuth().authenticate(reason: reason) == .success,
              let runtime = await AppModel.shared.loadRuntime() else {
            deletionFailed = true
            return
        }
        await ScreenUnlockController.shared.disable()
        do {
            try runtime.removeAllData()
        } catch {
            deletionFailed = true
        }
        await load()
    }
}
