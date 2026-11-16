import SwiftUI

/// Anneau de traits autour de l'aperçu : chaque secteur s'allume en vert quand la tête a
/// pointé dans sa direction (comme l'enregistrement Face ID sur iPhone).
struct EnrollmentRing: View {
    let filled: [Bool]
    let direction: Double?
    var tickCount = 72

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            ZStack {
                ForEach(0..<tickCount, id: \.self) { index in
                    let lit = isLit(index)
                    let near = isNearDirection(index)
                    Capsule()
                        .fill(lit ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color.secondary.opacity(near ? 0.75 : 0.3))
                        .frame(width: 3.5, height: lit ? 20 : (near ? 16 : 11))
                        .offset(y: -(radius - (lit ? 10 : 8)))
                        .rotationEffect(.degrees(Double(index) / Double(tickCount) * 360))
                        .animation(.easeOut(duration: 0.18), value: lit)
                }
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Progression de l’enregistrement"))
        .accessibilityValue(Text(verbatim: "\(filled.filter { $0 }.count)/\(filled.count)"))
    }

    /// L'angle des traits part du haut, dans le sens horaire ; celui des secteurs part de la
    /// droite de l'écran, dans le sens horaire.
    private func sectorAngle(forTick index: Int) -> Double {
        let fromTop = Double(index) / Double(tickCount) * 2 * .pi
        var fromRight = fromTop - .pi / 2
        if fromRight < 0 { fromRight += 2 * .pi }
        return fromRight
    }

    private func isLit(_ index: Int) -> Bool {
        guard !filled.isEmpty else { return false }
        let width = 2 * Double.pi / Double(filled.count)
        let sector = min(filled.count - 1, Int(sectorAngle(forTick: index) / width))
        return filled[sector]
    }

    private func isNearDirection(_ index: Int) -> Bool {
        guard let direction else { return false }
        var difference = abs(sectorAngle(forTick: index) - direction)
        if difference > .pi { difference = 2 * .pi - difference }
        return difference < .pi / 10
    }
}
