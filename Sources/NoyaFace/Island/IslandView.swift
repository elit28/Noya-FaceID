import SwiftUI

/// L'île : prolonge l'encoche vers la gauche (icône) et la droite (message). Sans encoche,
/// une pastille flotte sous la barre des menus. La fenêtre a une taille fixe ; seule la
/// forme noire s'anime à l'intérieur.
struct IslandView: View {
    let model: IslandModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let geometry = model.geometry
        ZStack(alignment: .top) {
            if geometry.hasNotch {
                notchIsland(geometry)
            } else {
                pill
                    .padding(.top, geometry.menuBarHeight + IslandMetrics.pillGap)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .modifier(ShakeEffect(shakes: CGFloat(model.shakes)))
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.3, dampingFraction: 0.78), value: model.expanded)
        .animation(reduceMotion ? nil : .linear(duration: 0.4), value: model.shakes)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(model.state?.text ?? ""))
    }

    private var wing: CGFloat {
        model.style == .sides ? IslandMetrics.sidesWing : IslandMetrics.discreetWing
    }

    private func notchIsland(_ geometry: IslandGeometry) -> some View {
        let open = model.expanded && model.state != nil
        let width = geometry.notch.width + (open ? wing * 2 : 0) + IslandMetrics.ear * 2
        return ZStack {
            NotchShape(ear: IslandMetrics.ear, bottomRadius: IslandMetrics.bottomRadius)
                .fill(Color.black)
            if open, let state = model.state {
                HStack(spacing: 0) {
                    icon(state)
                        .frame(width: wing)
                    Spacer(minLength: geometry.notch.width)
                    trailing(state)
                        .frame(width: wing)
                }
                .padding(.horizontal, IslandMetrics.ear)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .frame(width: width, height: geometry.notch.height)
    }

    @ViewBuilder
    private var pill: some View {
        let size = model.style == .sides ? IslandMetrics.pillSize : IslandMetrics.discreetPillSize
        if model.expanded, let state = model.state {
            HStack(spacing: 8) {
                icon(state)
                if model.style == .sides {
                    Text(state.text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(state.textColor)
                        .lineLimit(1)
                }
            }
            .frame(width: size.width, height: size.height)
            .background(Capsule().fill(Color.black))
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        }
    }

    private func icon(_ state: IslandState) -> some View {
        Image(systemName: state.symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(state.iconColor)
            .symbolEffect(.pulse, isActive: state == .searching && !reduceMotion)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func trailing(_ state: IslandState) -> some View {
        if model.style == .sides {
            Text(state.text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(state.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } else {
            Circle()
                .fill(state.iconColor)
                .frame(width: 7, height: 7)
        }
    }
}

/// Contour de l'île : un corps aux coins inférieurs arrondis, et deux petites « oreilles »
/// concaves en haut qui le fondent dans la barre des menus.
/// Adapté de HeyMac (MIT, `Island/NotchShape.swift`).
struct NotchShape: Shape {
    var ear: CGFloat
    var bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let ear = max(0, min(self.ear, rect.width / 2))
        let corner = max(0, min(bottomRadius, min(rect.width / 2 - ear, rect.height)))
        let overlap: CGFloat = 1
        let body = CGRect(x: rect.minX + ear, y: rect.minY, width: rect.width - 2 * ear, height: rect.height)
        var path = UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: corner,
            bottomTrailingRadius: corner, topTrailingRadius: 0,
            style: .continuous
        ).path(in: body)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: body.minX + overlap, y: rect.minY))
        path.addLine(to: CGPoint(x: body.minX + overlap, y: rect.minY + ear))
        path.addLine(to: CGPoint(x: body.minX, y: rect.minY + ear))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: body.minX, y: rect.minY))
        path.closeSubpath()

        path.move(to: CGPoint(x: body.maxX - overlap, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: body.maxX, y: rect.minY + ear), control: CGPoint(x: body.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: body.maxX - overlap, y: rect.minY + ear))
        path.closeSubpath()
        return path
    }
}

/// Léger tremblement horizontal lors d'un refus.
private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 5 * sin(shakes * .pi * 4), y: 0))
    }
}
