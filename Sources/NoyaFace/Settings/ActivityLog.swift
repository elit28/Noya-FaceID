import Foundation
import Observation
import SwiftUI

/// Activité récente, affichée dans le tableau de bord. En mémoire seulement : rien n'est
/// écrit sur le disque, et la liste se vide à la relance de l'app.
@MainActor
@Observable
final class ActivityLog {
    static let shared = ActivityLog()

    enum Kind {
        case success
        case refused
        case locked
    }

    struct Entry: Identifiable {
        let id = UUID()
        let date = Date()
        let kind: Kind
        let text: LocalizedStringKey
    }

    private(set) var entries: [Entry] = []
    private static let limit = 8

    private init() {}

    func record(_ kind: Kind, _ text: LocalizedStringKey) {
        entries.insert(Entry(kind: kind, text: text), at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
    }
}
