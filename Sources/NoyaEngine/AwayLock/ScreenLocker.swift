import ApplicationServices
import CoreGraphics
import Foundation

public enum ScreenLockerError: Error, Equatable {
    case accessibilityNotGranted
    case eventCreationFailed
}

/// Verrouille l'écran en envoyant le raccourci système documenté ⌃⌘Q (menu Pomme ›
/// Verrouiller l'écran). Envoyer un raccourci exige l'autorisation Accessibilité.
public enum ScreenLocker {
    public static var canLock: Bool { AXIsProcessTrusted() }

    public static func lock() throws {
        guard canLock else { throw ScreenLockerError.accessibilityNotGranted }
        let qKey: CGKeyCode = 0x0C // touche Q (code virtuel ANSI)
        let flags: CGEventFlags = [.maskControl, .maskCommand]
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: qKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: qKey, keyDown: false)
        else { throw ScreenLockerError.eventCreationFailed }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Secondes écoulées depuis la dernière action au clavier, à la souris ou au trackpad.
    public static func systemIdleSeconds() -> TimeInterval {
        // `kCGAnyInputEventType` (~0) : toutes les entrées confondues.
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}
