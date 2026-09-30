import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The settings page of one sidebar category.
struct CategoryDetail: View {
    let model: ConfiguratorModel
    let launcher: LaunchController
    let category: SettingCategory

    private var isLocked: Bool { !model.canEdit || launcher.isLaunching }

    var body: some View {
        switch category {
        case .play: LaunchGridView(model: model, launcher: launcher)
        case .about: AboutView(install: model.install)
        default: settingsForm
        }
    }

    private var settingsForm: some View {
        Form {
            if let error = model.loadError ?? model.saveError ?? launcher.error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(StatusTone.error.color)
                }
            }
            Group {
                ForEach(category.groups, id: \.title) { group in
                    Section {
                        if category == .launchOptions {
                            pathRow("ModOrganizer.exe", slot: .modOrganizer)
                            pathRow("Custom .exe", slot: .custom)
                        }
                        ForEach(group.settings, id: \.self) { setting in
                            SettingRow(model: model, setting: setting)
                        }
                    } header: {
                        Text(group.title)
                    } footer: {
                        if category == .launchOptions {
                            Text("Launch arguments apply to the custom .exe only. Game arguments for ModOrganizer are set in Mod Organizer.")
                        } else if let help = group.help {
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

    private func pathRow(_ title: String, slot: LaunchSlot) -> some View {
        let path = model.path(for: slot)
        return LabeledContent(title) {
            Text(path.isEmpty ? "Not set" : path)
                .foregroundStyle(path.isEmpty ? .secondary : .primary)
                .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
            Button("Choose…") { chooseTarget(slot) }
            if !path.isEmpty {
                Button("Clear") { model.clearTarget(slot) }
            }
        }
    }

    private func chooseTarget(_ slot: LaunchSlot) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "exe") ?? .data]
        panel.message = slot == .modOrganizer ? "Choose ModOrganizer.exe." : "Choose the Windows executable to launch."
        panel.begin { response in
            if response == .OK, let url = panel.url { model.selectTarget(url, slot: slot) }
        }
    }
}
