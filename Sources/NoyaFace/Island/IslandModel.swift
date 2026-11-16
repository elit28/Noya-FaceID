import AppKit
import Observation
import SwiftUI

/// États affichés par l'île (maquette Island validée).
enum IslandState: Equatable {
    case searching
    case success
    case refused
    case locking
    case unlocking

    var symbol: String {
        switch self {
        case .searching: return "viewfinder" // noloc
        case .success: return "checkmark" // noloc
        case .refused: return "xmark" // noloc
        case .locking: return "lock.fill" // noloc
        case .unlocking: return "lock.open.fill" // noloc
        }
    }

    var text: LocalizedStringKey {
        switch self {
        case .searching: return "Recherche…"
        case .success: return "Reconnu"
        case .refused: return "Non reconnu"
        case .locking: return "Verrouillé"
        case .unlocking: return "Déverrouillé"
        }
    }

    var iconColor: Color {
        switch self {
        case .searching, .locking: return .white
        case .success, .unlocking: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .refused: return Color(red: 1, green: 0.62, blue: 0.04)
        }
    }

    var textColor: Color {
        self == .refused ? Color(red: 1, green: 0.7, blue: 0.25) : .white
    }
}

/// Mesures de l'écran qui affiche l'île : encoche réelle, ou pastille sous la barre des menus.
struct IslandGeometry: Equatable {
    /// Largeur et hauteur de l'encoche (zéro sans encoche).
    var notch: CGSize
    /// Hauteur de la barre des menus, pour placer la pastille dessous.
    var menuBarHeight: CGFloat

    var hasNotch: Bool { notch.width > 0 }

    /// Écran avec encoche s'il y en a un, sinon l'écran principal.
    @MainActor
    static var preferredScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    /// Adapté de HeyMac (MIT, `Island/NotchGeometry.swift`) : l'encoche occupe ce que les
    /// deux moitiés de la barre des menus laissent libre (API publiques de NSScreen).
    @MainActor
    static func measure(_ screen: NSScreen) -> IslandGeometry {
        let menuBar = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
        let height = screen.safeAreaInsets.top
        guard height > 0 else { return IslandGeometry(notch: .zero, menuBarHeight: menuBar) }
        let halves = (screen.auxiliaryTopLeftArea?.width ?? 0) + (screen.auxiliaryTopRightArea?.width ?? 0)
        let width = max(screen.frame.width - halves, 160)
        return IslandGeometry(notch: CGSize(width: width, height: height), menuBarHeight: menuBar)
    }
}

enum IslandMetrics {
    static let sidesWing: CGFloat = 140
    static let discreetWing: CGFloat = 50
    static let pillSize = CGSize(width: 190, height: 34)
    static let discreetPillSize = CGSize(width: 70, height: 34)
    static let pillGap: CGFloat = 8
    static let bottomRadius: CGFloat = 14
    static let ear: CGFloat = 6
}

@MainActor
@Observable
final class IslandModel {
    var state: IslandState?
    var expanded = false
    var geometry = IslandGeometry(notch: .zero, menuBarHeight: 24)
    var style: IslandStyle = .sides
    /// Incrémenté à chaque refus, pour le léger tremblement.
    var shakes = 0
}
