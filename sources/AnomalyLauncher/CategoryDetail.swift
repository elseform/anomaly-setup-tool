import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The settings page of one sidebar category.
struct CategoryDetail: View {
    let model: ConfiguratorModel
    let launcher: LaunchController
    let category: SettingCategory

    private var isLocked: Bool { !model.canEdit || launcher.isRunning }

    var body: some View {
        switch category {
        case .play: LaunchGridView(model: model, launcher: launcher)
        case .executables: executablesForm
        case .about: AboutView(model: model, isLocked: isLocked)
        default: settingsForm
        }
    }

    private var errorSection: some View {
        Group {
            if let error = model.loadError ?? model.saveError ?? launcher.error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(StatusTone.error.color)
                }
            }
        }
    }

    private var settingsForm: some View {
        Form {
            errorSection
            Group {
                ForEach(category.groups, id: \.title) { group in
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
            .id(model.revision)
            .disabled(isLocked)
        }
        .formStyle(.grouped)
    }

    /// Mod Organizer's path, then one section per custom executable, each with
    /// its own startup arguments.
    private var executablesForm: some View {
        Form {
            errorSection
            Group {
                Section {
                    modOrganizerRow
                } header: {
                    Text(category.title)
                } footer: {
                    Text("Game arguments for ModOrganizer are set in Mod Organizer.")
                }
                ForEach(model.customExecutables) { executable in
                    CustomExecutableSection(model: model, executable: executable)
                }
                Section {
                    Button("Add custom executable…", action: chooseCustomExecutable)
                }
            }
            .id(model.revision)
            .disabled(isLocked)
        }
        .formStyle(.grouped)
    }

    private var modOrganizerRow: some View {
        let path = model.modOrganizerPath
        return LabeledContent("ModOrganizer.exe") {
            Text(path.isEmpty ? "Not set" : path)
                .foregroundStyle(path.isEmpty ? .secondary : .primary)
                .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
            Button("Choose…") { chooseExecutable(message: "Choose ModOrganizer.exe.", onSelect: model.selectModOrganizer) }
            if !path.isEmpty {
                Button("Clear") { model.clearModOrganizer() }
            }
        }
    }

    private func chooseCustomExecutable() {
        chooseExecutable(message: "Choose the Windows executable to launch.", onSelect: model.addCustomExecutable)
    }

    private func chooseExecutable(message: String, onSelect: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "exe") ?? .data]
        panel.message = message
        panel.begin { response in
            if response == .OK, let url = panel.url { onSelect(url) }
        }
    }
}

/// A chosen custom executable: its tile name with a button to remove it, its
/// path, and its startup arguments.
private struct CustomExecutableSection: View {
    let model: ConfiguratorModel
    let executable: CustomExecutable

    var body: some View {
        Section {
            LabeledContent {
                HStack {
                    CommitTextField(
                        text: Binding(get: { executable.name }, set: { model.setCustomName(executable.id, $0, save: false) }),
                        prompt: executable.defaultName
                    ) { model.persist() }
                        .accessibilityLabel("Name of \(executable.path)")
                    Button("Remove \(executable.label)", systemImage: "minus.circle") {
                        model.removeCustomExecutable(executable.id)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom executable")
                    Text(executable.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                }
            }
            LabeledContent {
                CommitTextField(
                    text: Binding(get: { executable.arguments }, set: { model.setCustomArguments(executable.id, $0, save: false) })
                ) { model.persist() }
                    .accessibilityLabel("Startup arguments for \(executable.label)")
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Startup arguments")
                    Text("Extra arguments passed to this executable when it starts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
