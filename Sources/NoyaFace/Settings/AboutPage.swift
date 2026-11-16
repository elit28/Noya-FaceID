import SwiftUI

/// À propos et licences.
struct AboutPage: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: BrandMark.appIconImage(size: 72))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: AppInfo.name)
                            .font(.title.weight(.bold))
                        Text("Version \(AppInfo.version)")
                            .foregroundStyle(.secondary)
                        Text("Libre et gratuit, par NOYA 360.")
                            .foregroundStyle(.secondary)
                    }
                }
                if let site = URL(string: AppInfo.websiteURL) {
                    Link(destination: site) { Text(verbatim: AppInfo.websiteURL) }
                }
                if let repository = URL(string: AppInfo.repositoryURL) {
                    Link(destination: repository) { Text("Code source sur GitHub") }
                }
            }

            Section("Confidentialité") {
                Text("Traitement entièrement local. Aucune image n’est enregistrée, aucune donnée n’est envoyée.")
            }

            Section("Licences") {
                Text("Code sous licence MIT. Le logo NOYA est une marque de NOYA 360, non couverte par cette licence.")
                Text("Composants tiers : HeyMac (MIT), Silent-Face-Anti-Spoofing (Apache-2.0), SFace d’OpenCV Zoo (Apache-2.0). Détails dans THIRD_PARTY_NOTICES.md.")
                    .foregroundStyle(.secondary)
                Text("NOYA Face n’est pas affilié à Apple. « Face ID » est une marque d’Apple Inc.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
