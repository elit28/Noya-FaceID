import SwiftUI

/// Ajout d'une apparence (lunettes, barbe…) : deux tours de tête, comme l'enregistrement,
/// refusé si le visage ne correspond pas au vôtre.
struct AppearanceEnrollmentView: View {
    let onFinish: (Bool) -> Void

    @State private var name = String(localized: "Avec lunettes")
    @State private var started = false
    @State private var model = EnrollmentModel()
    @State private var permissions = PermissionsModel()

    var body: some View {
        VStack(spacing: 16) {
            if started {
                EnrollmentStep(model: model, permissions: permissions)
            } else {
                Text("Nouvelle apparence")
                    .font(.title2.weight(.bold))
                Text("Donnez-lui un nom, puis faites deux tours de tête comme lors de l’enregistrement.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                TextField("Nom de l’apparence", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
            }
            HStack {
                Button("Annuler") {
                    model.cancel()
                    onFinish(false)
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                if !started {
                    Button("Continuer") {
                        model.appearanceName = name.trimmingCharacters(in: .whitespaces)
                        started = true
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    Button("Terminer") { onFinish(true) }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.phase != .done)
                }
            }
        }
        .padding(24)
        .frame(width: 560, height: started ? 600 : 260)
        .onAppear { permissions.refresh() }
    }
}
