import SwiftUI

struct SchemaRow: View {
    let model: ConfiguratorModel
    let entry: SchemaEntry

    private var current: VarEntry { model.varEntry(for: entry) }
    private var text: Binding<String> {
        Binding(get: { current.value }, set: { model.setVar(entry.key, enabled: current.enabled, value: $0, save: false) })
    }

    var body: some View {
        switch entry.kind {
        case .retina, .bool:
            Toggle(isOn: Binding(get: {
                current.enabled && current.value == (entry.kind == .retina ? "Y" : "1")
            }, set: { on in
                model.setVar(entry.key, enabled: entry.alwaysOn || on,
                             value: entry.kind == .retina ? (on ? "Y" : "N") : (on ? "1" : "0"))
            })) { SettingLabel(key: entry.key) }
        default:
            LabeledContent {
                HStack {
                    if !entry.alwaysOn {
                        Toggle("Use \(friendlyLabel(for: entry.key))", isOn: Binding(get: { current.enabled }, set: {
                            model.setVar(entry.key, enabled: $0, value: current.value)
                        }))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                    }
                    CommitTextField(text: text, isEnabled: entry.alwaysOn || current.enabled) { model.persist() }
                        .accessibilityLabel(friendlyLabel(for: entry.key))
                }
            } label: { SettingLabel(key: entry.key) }
        }
    }
}

struct DXMTConfigRow: View {
    let model: ConfiguratorModel
    let entry: DXMTConfigEntry
    private var current: VarEntry { model.dxmtEntry(for: entry) }
    private var options: [String]? {
        switch entry.kind {
        case .bool: ["true", "false"]
        case .enumChoice: entry.choices
        default: nil
        }
    }

    var body: some View {
        if let options {
            Picker(selection: Binding<String?>(get: { current.enabled ? current.value : nil }, set: {
                model.setDXMT(entry.key, enabled: $0 != nil, value: $0 ?? current.value)
            })) {
                Text("Default").tag(String?.none)
                ForEach(options, id: \.self) { option in
                    Text(displayName(for: option)).tag(String?.some(option))
                }
            } label: { SettingLabel(key: entry.key) }
        } else {
            LabeledContent {
                HStack {
                    Toggle("Use \(friendlyLabel(for: entry.key))", isOn: Binding(get: { current.enabled }, set: {
                        model.setDXMT(entry.key, enabled: $0, value: current.value)
                    }))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    CommitTextField(text: Binding(get: { current.value }, set: {
                        model.setDXMT(entry.key, enabled: current.enabled, value: $0, save: false)
                    }), isEnabled: current.enabled) { model.persist() }
                        .accessibilityLabel(friendlyLabel(for: entry.key))
                }
            } label: { SettingLabel(key: entry.key) }
        }
    }

    private func displayName(for option: String) -> String {
        switch option {
        case "true": "On"
        case "false": "Off"
        case "auto": "Auto"
        default: option
        }
    }
}

/// Renders an app.env or DXMT_CONFIG row, hidden while its parent switch is off.
struct SettingRow: View {
    let model: ConfiguratorModel
    let setting: SettingRef

    var body: some View {
        if model.isVisible(setting) {
            switch setting {
            case .env(let key):
                if let entry = schemaByKey[key] {
                    SchemaRow(model: model, entry: entry)
                        .disabled(key == "DEFAULT_GAME_ARGS" && model.isModOrganizer)
                }
            case .dxmt(let key):
                if let entry = dxmtConfigByKey[key] {
                    DXMTConfigRow(model: model, entry: entry)
                }
            }
        }
    }
}

struct ConfiguratorView: View {
    let model: ConfiguratorModel
    let launcher: LaunchController
    @AppStorage("launcherCategory") private var category = SettingCategory.launch
    @State private var confirmReset = false

    private var isLocked: Bool { !model.canEdit || launcher.isLaunching }

    var body: some View {
        NavigationSplitView {
            LauncherSidebar(model: model, selection: $category)
        } detail: {
            CategoryDetail(model: model, launcher: launcher, category: category)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                bottomBar
            }
            .background(.bar)
        }
        .frame(minWidth: Layout.minimumWidth, minHeight: Layout.minimumHeight)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Link(Links.githubTitle, destination: Links.githubURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(Links.githubHelp)
            Link(Links.discordTitle, destination: Links.discordURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(Links.discordHelp)
            Spacer()
            Text("Settings save automatically.").font(.caption).foregroundStyle(.tertiary)
            Button("Reset to Defaults…", role: .destructive) {
                confirmReset = true
            }
            .disabled(isLocked)
            .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive, action: model.resetToDefaults)
            } message: {
                Text("Every setting, including launch arguments, goes back to what a new install starts with.")
            }
            Button(launcher.isLaunching ? "Launching…" : "Launch") { launcher.launch(model: model) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: .command)
                .disabled(isLocked)
        }
        .padding()
    }
}
