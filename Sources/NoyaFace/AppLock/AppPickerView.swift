import AppKit
import NoyaEngine
import SwiftUI
import UniformTypeIdentifiers

/// Application proposée dans le sélecteur.
struct PickerApp: Identifiable, Hashable, Sendable {
    let bundleID: String
    let name: String
    let path: String?
    var id: String { bundleID }
}

/// « Choisir les applications à protéger » (maquette AppPicker validée) : recherche,
/// suggestions, liste des apps installées et « Autre application… ».
struct AppPickerView: View {
    let onCancel: () -> Void
    let onConfirm: ([PickerApp]) -> Void

    @State private var apps: [PickerApp]
    @State private var selection: Set<String>
    @State private var loading = true
    @State private var query = ""

    init(current: [LockedApp], onCancel: @escaping () -> Void, onConfirm: @escaping ([PickerApp]) -> Void) {
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _apps = State(initialValue: current.map { PickerApp(bundleID: $0.bundleID, name: $0.name, path: nil) })
        _selection = State(initialValue: Set(current.map(\.bundleID)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Choisir les applications à protéger")
                .font(.title2.weight(.bold))
            Text("Applications installées sur ce Mac.")
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            TextField("Rechercher une application", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.top, 14)

            List {
                if query.isEmpty && !suggestions.isEmpty {
                    Section("Suggestions") {
                        ForEach(suggestions) { row($0) }
                    }
                }
                Section(listTitle) {
                    if loading {
                        ProgressView().controlSize(.small)
                    } else if filtered.isEmpty {
                        Text("Aucune application ne correspond à « \(query) ».")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filtered) { row($0) }
                    }
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 300)
            .padding(.top, 10)

            Text("Toujours accessibles, pour pouvoir corriger une erreur : Terminal, Réglages Système, Moniteur d’activité, Finder et NOYA Face.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            HStack {
                Button("Autre application…") { chooseOtherApp() }
                Spacer()
                Text(countLabel)
                    .foregroundStyle(.secondary)
                Button("Annuler", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Protéger") {
                    onConfirm(apps.filter { selection.contains($0.bundleID) })
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 14)
        }
        .padding(24)
        .frame(width: 560, height: 640)
        .task { await loadInstalledApps() }
    }

    private var suggestions: [PickerApp] {
        AppLockKeys.suggestedBundleIDs.compactMap { id in apps.first { $0.bundleID == id && $0.path != nil } }
    }

    private var filtered: [PickerApp] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private var listTitle: LocalizedStringKey {
        query.isEmpty ? "Toutes les applications" : "Résultats"
    }

    private var countLabel: LocalizedStringKey {
        selection.count > 1
            ? "\(selection.count) applications sélectionnées"
            : "\(selection.count) application sélectionnée"
    }

    private func row(_ app: PickerApp) -> some View {
        Toggle(isOn: Binding(
            get: { selection.contains(app.bundleID) },
            set: { isOn in
                if isOn { selection.insert(app.bundleID) } else { selection.remove(app.bundleID) }
            }
        )) {
            HStack(spacing: 10) {
                AppIconView(bundleID: app.bundleID, path: app.path, size: 24)
                Text(app.name)
                Spacer()
                if selection.contains(app.bundleID) {
                    Text("Sera protégée")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.checkbox)
    }

    private func loadInstalledApps() async {
        let installed = await Task.detached(priority: .userInitiated) {
            InstalledApps.scan().map { PickerApp(bundleID: $0.bundleID, name: $0.name, path: $0.url.path) }
        }.value
        var merged = installed
        // Les apps déjà protégées mais introuvables dans les dossiers habituels restent listées.
        for app in apps where !installed.contains(where: { $0.bundleID == app.bundleID }) {
            merged.append(app)
        }
        apps = merged.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        loading = false
    }

    private func chooseOtherApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: AppLockKeys.applicationsFolder)
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier, !AppLockBlacklist.isProtected(bundleID) else { return }
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "") // noloc
        if !apps.contains(where: { $0.bundleID == bundleID }) {
            apps.append(PickerApp(bundleID: bundleID, name: name, path: url.path))
        }
        selection.insert(bundleID)
    }
}

/// Icône d'une app, depuis son chemin ou son identifiant.
struct AppIconView: View {
    let bundleID: String
    let path: String?
    let size: CGFloat

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var icon: NSImage {
        if let path { return NSWorkspace.shared.icon(forFile: path) }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
}
