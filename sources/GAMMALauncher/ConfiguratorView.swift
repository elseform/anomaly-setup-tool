import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    @AppStorage("advancedExpanded") private var showAdvanced = false
    @State private var confirmReset = false
    /// Height of everything in the form, so the window can match it.
    @State private var contentHeight: CGFloat = Layout.initialHeight

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Launch Target") {
                    LabeledContent("Executable") {
                        Text(model.targetPath.isEmpty ? "Choose an executable" : model.targetPath)
                            .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                        Button("Choose…", action: chooseTarget)
                            .disabled(!model.canEdit || launcher.isLaunching)
                    }
                    if model.isModOrganizer {
                        Text("Game launch arguments are configured in Mod Organizer. Press Run there to start the game.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let error = model.loadError ?? model.saveError ?? launcher.error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(StatusTone.error.color)
                    }
                }

                Group {
                    ForEach(mainGroups, id: \.title) { group in
                        section(for: group)
                    }

                    advancedToggle

                    if showAdvanced {
                        ForEach(advancedGroups, id: \.title) { group in
                            section(for: group)
                        }
                    }
                }
                .id(model.revision)
                .disabled(!model.canEdit || launcher.isLaunching)

                Section {
                    Button("Reset to Defaults…", role: .destructive) {
                        confirmReset = true
                    }
                    .disabled(!model.canEdit || launcher.isLaunching)
                }
            }
            .formStyle(.grouped)
            .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive, action: model.resetToDefaults)
            } message: {
                Text("Every setting, including launch arguments, goes back to what a new install starts with.")
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom
            } action: { _, height in
                contentHeight = height
            }
            // The window follows this size (.windowResizability(.contentSize));
            // past the screen's height the form scrolls instead.
            .frame(height: min(contentHeight, Layout.maximumHeight - 64))
            Divider()
            HStack {
                Text("Settings save automatically.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(launcher.isLaunching ? "Launching…" : "Launch") { launcher.launch(model: model) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(!model.canEdit || launcher.isLaunching)
            }
            .padding()
        }
        .frame(width: Layout.windowWidth)
    }

    private func chooseTarget() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "exe") ?? .data]
        panel.message = "Choose the Windows executable this wrapper launches."
        panel.begin { response in
            if response == .OK, let url = panel.url { model.selectTarget(url) }
        }
    }

    private var advancedToggle: some View {
        Section {
            Button {
                showAdvanced.toggle()
            } label: {
                HStack {
                    Text(showAdvanced ? "Hide Advanced Settings" : "Show Advanced Settings")
                    Spacer()
                    let changed = model.advancedChangedCount
                    if changed > 0 {
                        Text("\(changed) changed")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        } footer: {
            Text("For troubleshooting. Most players never need these.")
        }
    }

    private func section(for group: SettingGroup) -> some View {
        Section {
            ForEach(group.settings, id: \.self) { setting in
                SettingRow(model: model, setting: setting)
            }
        } header: {
            Text(group.title)
        } footer: {
            if let help = group.help {
                Text(help)
            }
        }
    }
}
