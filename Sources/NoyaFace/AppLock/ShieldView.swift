import AppKit
import Observation
import SwiftUI

/// État affiché par le bouclier d'une app protégée.
@MainActor
@Observable
final class ShieldModel {
    enum Phase: Equatable {
        case scanning
        case refused(Refusal)
        case system
        case unlocked
    }

    enum Refusal: Equatable {
        case notRecognized
        case unavailable
        case noFace
        case cancelled
        case systemFailed
    }

    var appName = ""
    var icon: NSImage?
    var phase: Phase = .scanning
    var faceAvailable = true
    /// L'écran qui affiche la carte ; les autres sont seulement masqués.
    var primaryDisplayID: CGDirectDisplayID?
    var onUseSystem: () -> Void = {}
    var onRetry: () -> Void = {}
    var onQuitApp: () -> Void = {}
}

/// Masque plein écran (opaque par défaut, flou en option) et carte centrale (maquette
/// « Shield » validée).
struct ShieldView: View {
    let model: ShieldModel
    let displayID: CGDirectDisplayID
    @AppStorage(AppLockKeys.mask) private var mask: ShieldMask = .opaque

    var body: some View {
        ZStack {
            switch mask {
            case .opaque:
                Color(nsColor: ShieldColors.mask)
            case .blur:
                ShieldBlur()
                Color(nsColor: ShieldColors.mask).opacity(0.35)
            }
            if model.primaryDisplayID == displayID {
                ShieldCard(model: model)
            }
        }
        .ignoresSafeArea()
    }
}

enum ShieldColors {
    /// Gris clair en apparence claire, presque noir en apparence sombre (maquette).
    static var mask: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.078, green: 0.078, blue: 0.09, alpha: 1)
                : NSColor(srgbRed: 0.91, green: 0.91, blue: 0.929, alpha: 1)
        }
    }
}

private struct ShieldBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

private struct ShieldCard: View {
    let model: ShieldModel

    var body: some View {
        VStack(spacing: 0) {
            appIcon
            Text("\(model.appName) est protégée")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 10) {
                statusIcon
                Text(statusText)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 28)
            .padding(.top, 14)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)

            VStack(spacing: 8) {
                if showsSystemButton {
                    Button {
                        model.onUseSystem()
                    } label: {
                        Text("Utiliser Touch ID ou le mot de passe").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
                if showsRetry {
                    Button {
                        model.onRetry()
                    } label: {
                        Text("Réessayer avec mon visage").frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
                if model.phase != .unlocked {
                    Button("Quitter \(model.appName)") { model.onQuitApp() }
                        .buttonStyle(.link)
                        .padding(.top, 2)
                }
            }
            .padding(.top, 20)

            Text("Protection de confidentialité NOYA Face. \(model.appName) reste ouverte en arrière-plan.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
        }
        .padding(EdgeInsets(top: 28, leading: 28, bottom: 22, trailing: 28))
        .frame(width: 400)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(nsColor: .windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.09)))
        .shadow(color: .black.opacity(0.18), radius: 30, y: 12)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = model.icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
        } else {
            Image(nsImage: BrandMark.appIconImage(size: 64))
                .accessibilityHidden(true)
        }
    }

    private var statusIcon: some View {
        Image(systemName: statusSymbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(statusColor)
            .symbolEffect(.pulse, isActive: model.phase == .scanning)
            .accessibilityHidden(true)
    }

    private var statusSymbol: String {
        switch model.phase {
        case .scanning: return "viewfinder" // noloc
        case .refused: return "xmark" // noloc
        case .system: return "touchid" // noloc
        case .unlocked: return "checkmark" // noloc
        }
    }

    private var statusColor: Color {
        switch model.phase {
        case .scanning, .system: return .accentColor
        case .refused: return .orange
        case .unlocked: return .green
        }
    }

    private var statusText: LocalizedStringKey {
        switch model.phase {
        case .scanning: return "Regardez l’écran…"
        case .system: return "Authentification système…"
        case .unlocked: return "Accès accordé"
        case .refused(let refusal):
            switch refusal {
            case .notRecognized: return "Visage non reconnu"
            case .unavailable: return "Reconnaissance faciale indisponible"
            case .noFace: return "Aucun visage enregistré"
            case .cancelled: return "Authentification annulée"
            case .systemFailed: return "Authentification refusée"
            }
        }
    }

    private var showsSystemButton: Bool {
        switch model.phase {
        case .scanning, .refused: return true
        case .system, .unlocked: return false
        }
    }

    private var showsRetry: Bool {
        if case .refused = model.phase { return model.faceAvailable }
        return false
    }
}
