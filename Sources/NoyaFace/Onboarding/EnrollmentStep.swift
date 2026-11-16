import NoyaEngine
import SwiftUI

/// Étape « Visage » : deux tours de tête, aperçu caméra en miroir et anneau de progression.
struct EnrollmentStep: View {
    let model: EnrollmentModel
    let permissions: PermissionsModel

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.largeTitle.weight(.bold))
            Text(hint)
                .foregroundStyle(model.issue == nil ? Color.secondary : Color.orange)
                .multilineTextAlignment(.center)
                .frame(minHeight: 22)
                .padding(.top, 6)
                .accessibilityAddTraits(.updatesFrequently)

            ZStack {
                EnrollmentRing(filled: model.filled, direction: model.direction)
                Group {
                    if model.phase == .done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 80, weight: .semibold))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.9))
                    } else if isScanning, let session = AppModel.shared.runtime?.camera.captureSession {
                        CameraPreview(session: session)
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 96, weight: .ultraLight))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.85))
                    }
                }
                .frame(width: 216, height: 216)
                .clipShape(Circle())
                .accessibilityHidden(true)
            }
            .frame(width: 300, height: 300)
            .padding(.top, 14)

            controls
                .padding(.top, 16)
        }
        .task { await model.prepare() }
        .onDisappear { model.cancel() }
    }

    private var isScanning: Bool {
        if case .scanning = model.phase { return true }
        return false
    }

    @ViewBuilder
    private var controls: some View {
        switch model.phase {
        case .loading:
            ProgressView().controlSize(.small)
        case .ready:
            VStack(spacing: 10) {
                Button("Commencer le scan") { model.startScan() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!permissions.cameraGranted)
                Toggle("Options d’accessibilité : mouvement de tête réduit", isOn: Binding(
                    get: { model.partialCircle }, set: { model.setPartialCircle($0) }
                ))
                .toggleStyle(.checkbox)
                .font(.callout)
                .help(Text("Un demi-cercle suffit, avec de plus petits mouvements de tête."))
            }
        case .scanning:
            Button("Annuler") { model.cancel() }
        case .betweenScans:
            Button("Continuer") { model.startScan() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .saving:
            ProgressView().controlSize(.small)
        case .done:
            Text("Aucune image n’a été conservée : seules des empreintes chiffrées.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .failed:
            Button("Réessayer") { model.restart() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private var title: LocalizedStringKey {
        switch model.phase {
        case .loading, .ready: return "Enregistrement de votre visage"
        case .scanning(let index): return index == 0 ? "Premier scan" : "Deuxième scan"
        case .betweenScans: return "Premier scan terminé"
        case .saving: return "Enregistrement…"
        case .done: return "Visage enregistré"
        case .failed: return "Enregistrement interrompu"
        }
    }

    private var hint: LocalizedStringKey {
        if !permissions.cameraGranted {
            return "Autorisez d’abord la caméra à l’étape précédente."
        }
        if let issue = model.issue {
            switch issue {
            case .multipleFaces: return "Deux visages détectés : restez seul face à la caméra."
            case .tooFar: return "Rapprochez-vous de l’écran."
            case .notLive: return "Visage non confirmé : évitez les reflets et restez face à la caméra."
            case .noFace: return "Placez votre visage dans le cercle."
            }
        }
        switch model.phase {
        case .loading: return "Préparation de la reconnaissance…"
        case .ready: return "Placez votre visage dans le cercle, à une longueur de bras de l’écran."
        case .scanning: return model.calibrating ? "Regardez l’écran, de face." : "Bougez lentement la tête pour compléter le cercle."
        case .betweenScans: return "Encore un tour, un peu plus lentement si possible."
        case .saving: return "Chiffrement et enregistrement sur ce Mac…"
        case .done: return "Votre visage est enregistré sur ce Mac."
        case .failed(let reason):
            switch reason {
            case .engineUnavailable: return "Le moteur de reconnaissance n’a pas pu démarrer. Voir Diagnostic."
            case .cameraUnavailable: return "Caméra indisponible. Vérifiez qu’aucune autre app ne l’utilise."
            case .cameraBusy: return "La caméra est occupée par une autre vérification. Réessayez."
            case .timedOut: return "Le cercle n’a pas été complété à temps. Réessayez en tournant lentement la tête."
            case .saveFailed: return "L’enregistrement a échoué. Réessayez."
            }
        }
    }
}
