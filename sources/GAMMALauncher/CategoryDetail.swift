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
                        if category == .launch {
                            executableRow
                        }
                        ForEach(group.settings, id: \.self) { setting in
                            SettingRow(model: model, setting: setting)
                        }
                    } header: {
                        Text(group.title)
                    } footer: {
                        if category == .launch && model.isModOrganizer {
                            Text("Game launch arguments are configured in Mod Organizer. Press Run there to start the game.")
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

    private var executableRow: some View {
        LabeledContent("Executable") {
            Text(model.targetPath.isEmpty ? "Choose an executable" : model.targetPath)
                .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
            Button("Choose…", action: chooseTarget)
        }
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
}
