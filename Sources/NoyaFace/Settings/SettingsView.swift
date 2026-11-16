import SwiftUI

/// Pages de la fenêtre principale (maquette Main validée).
enum SettingsPage: String, CaseIterable, Identifiable {
    case dashboard, face, security, apps, appearance, advanced, diagnostic, about

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard: return "Tableau de bord"
        case .face: return "Mon visage"
        case .security: return "Sécurité"
        case .apps: return "Applications protégées"
        case .appearance: return "Apparence"
        case .advanced: return "Paramètres avancés"
        case .diagnostic: return "Diagnostic"
        case .about: return "À propos"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent" // noloc
        case .face: return "faceid" // noloc
        case .security: return "lock.shield" // noloc
        case .apps: return "square.grid.2x2" // noloc
        case .appearance: return "paintbrush" // noloc
        case .advanced: return "gearshape.2" // noloc
        case .diagnostic: return "stethoscope" // noloc
        case .about: return "info.circle" // noloc
        }
    }
}

/// Fenêtre principale : barre latérale et pages.
struct SettingsView: View {
    @State private var page: SettingsPage? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $page) { page in
                Label(page.title, systemImage: page.symbol)
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            let current = page ?? .dashboard
            Group {
                switch current {
                case .dashboard: DashboardPage(navigate: { page = $0 })
                case .face: FacePage()
                case .security: SecurityPage()
                case .apps: Form { ProtectedAppsSection() }.formStyle(.grouped)
                case .appearance: AppearancePage()
                case .advanced: AdvancedPage()
                case .diagnostic: DiagnosticPage()
                case .about: AboutPage()
                }
            }
            .navigationTitle(Text(current.title))
        }
        .frame(minWidth: 820, minHeight: 600)
    }
}
