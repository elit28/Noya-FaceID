import AppKit

/// Logo NOYA Face : le « N » de NOYA 360 dans un cadre façon Face ID.
/// Les images viennent de `packaging/brand` (scripts/generate-app-icon.py) ; à défaut (lancement
/// hors de l'app assemblée), un tracé de secours est dessiné par le code dans une grille de
/// 32 unités.
enum BrandMark {
    /// Silhouette du N (seule sa transparence compte), copiée dans Contents/Resources.
    private static let letterImageName = "BrandN" // noloc

    /// Icône de la barre des menus : image modèle (template) qui suit le thème de macOS.
    static func menuBarImage() -> NSImage {
        let size: CGFloat = 18
        let letter = NSImage(named: letterImageName)
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            if let letter {
                drawFrame(in: rect, gridOrigin: 6, gridSize: 20, color: .black)
                // Le N occupe le centre du cadre (unités 11 à 21 de la grille).
                let unit = rect.width / 20
                let width = 11.5 * unit
                let height = width * letter.size.height / max(letter.size.width, 1)
                let box = NSRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
                letter.draw(in: box, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            } else {
                drawGlyph(in: rect, gridOrigin: 6, gridSize: 20, color: .black)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Icône de l'application, pour l'affichage dans l'app.
    static func appIconImage(size: CGFloat) -> NSImage {
        if Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") != nil, // noloc
           let icon = NSImage(named: NSImage.applicationIconName)?.copy() as? NSImage {
            icon.size = NSSize(width: size, height: size)
            return icon
        }
        return NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            let radius = rect.width * 8 / 32
            let background = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
            NSColor(srgbRed: 0x14 / 255, green: 0x14 / 255, blue: 0x16 / 255, alpha: 1).setFill()
            background.fill()
            NSColor(white: 1, alpha: 0.14).setStroke()
            background.lineWidth = 1
            background.stroke()
            drawGlyph(in: rect, gridOrigin: 0, gridSize: 32, color: .white)
            return true
        }
    }

    private static func drawFrame(in rect: NSRect, gridOrigin: CGFloat, gridSize: CGFloat, color: NSColor) {
        drawGlyph(in: rect, gridOrigin: gridOrigin, gridSize: gridSize, color: color, includeLetter: false)
    }

    /// Trace le cadre et le « N ». `gridOrigin`/`gridSize` choisissent la portion de la grille
    /// de 32 unités affichée dans `rect` (repère retourné : y vers le bas).
    private static func drawGlyph(in rect: NSRect, gridOrigin: CGFloat, gridSize: CGFloat, color: NSColor,
                                  includeLetter: Bool = true) {
        let scale = rect.width / gridSize
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: rect.minX + (x - gridOrigin) * scale, y: rect.minY + (y - gridOrigin) * scale)
        }

        let frame = NSBezierPath()
        // Coin haut gauche.
        frame.move(to: point(8, 12.5))
        frame.line(to: point(8, 10))
        frame.appendArc(from: point(8, 8), to: point(10, 8), radius: 2 * scale)
        frame.line(to: point(12.5, 8))
        // Coin haut droit.
        frame.move(to: point(19.5, 8))
        frame.line(to: point(22, 8))
        frame.appendArc(from: point(24, 8), to: point(24, 10), radius: 2 * scale)
        frame.line(to: point(24, 12.5))
        // Coin bas droit.
        frame.move(to: point(24, 19.5))
        frame.line(to: point(24, 22))
        frame.appendArc(from: point(24, 24), to: point(22, 24), radius: 2 * scale)
        frame.line(to: point(19.5, 24))
        // Coin bas gauche.
        frame.move(to: point(12.5, 24))
        frame.line(to: point(10, 24))
        frame.appendArc(from: point(8, 24), to: point(8, 22), radius: 2 * scale)
        frame.line(to: point(8, 19.5))
        frame.lineWidth = 1.8 * scale
        frame.lineCapStyle = .round

        let letter = NSBezierPath()
        letter.move(to: point(12.75, 20))
        letter.line(to: point(12.75, 12))
        letter.line(to: point(19.25, 20))
        letter.line(to: point(19.25, 12))
        letter.lineWidth = 2.1 * scale
        letter.lineCapStyle = .round
        letter.lineJoinStyle = .round

        color.setStroke()
        frame.stroke()
        if includeLetter { letter.stroke() }
    }
}
