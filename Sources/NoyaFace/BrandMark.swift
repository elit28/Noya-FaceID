import AppKit

/// Logo NOYA Face dessiné par le code : le cadre façon Face ID et un « N ».
/// Géométrie exprimée dans une grille de 32 unités, identique à la maquette validée.
enum BrandMark {
    /// Icône de la barre des menus : image modèle (template) qui suit le thème de macOS.
    static func menuBarImage() -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            drawGlyph(in: rect, gridOrigin: 6, gridSize: 20, color: .black)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Icône de l'application (fond noir arrondi, tracé blanc), pour l'affichage dans l'app.
    static func appIconImage(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
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

    /// Trace le cadre et le « N ». `gridOrigin`/`gridSize` choisissent la portion de la grille
    /// de 32 unités affichée dans `rect` (repère retourné : y vers le bas).
    private static func drawGlyph(in rect: NSRect, gridOrigin: CGFloat, gridSize: CGFloat, color: NSColor) {
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
        letter.stroke()
    }
}
