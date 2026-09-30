import SwiftUI

#if SWIFT_PACKAGE
import AnomalySetupCore
#endif

struct SetupPage: View {
    @Bindable var model: AppModel

    @State private var advancedIsOpen = false
    @State private var redistInstallerStatuses: [RedistInstallers.Status] = []

    // MARK: - Body

    var body: some View {
        let ready = model.selectedLaunchExecutableFound && !model.isRunning
        Form {
            Group {
                engineArchiveControls
                redistInstallerControls
                advancedControls
            }
            .disabled(!ready)
            .opacity(ready ? 1 : 0.45)
        }
        .pageForm()
    }

    // MARK: - Engine archive

    // Left on the default, the newest published anomaly-wine-engine release
    // is resolved and downloaded automatically; the local choice takes an
    // archive path, used as is.
    private var engineArchiveControls: some View {
        Section {
            Picker("Engine source", selection: $model.usesLocalEngine) {
                Text("Download the latest release from GitHub").tag(false)
                Text("Provide engine locally").tag(true)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            if model.usesLocalEngine {
                HStack(spacing: 8) {
                    TextField("Engine archive", text: $model.wineEngineArchivePath, prompt: Text("Path to a .tar.xz engine archive"))
                        .accessibilityLabel("Engine archive")
                    Button("Choose…") {
                        model.chooseWineEngineArchive()
                    }
                    .accessibilityLabel("Choose engine archive")
                }
            }
        } header: {
            Text("Wine Engine")
        }
    }

    // MARK: - Redistributables

    // The DirectX/VC++ DLLs are not shipped with the engine — it declares
    // which ones it needs and fetches them from Microsoft's own pinned
    // installers during setup. Nothing here has to be filled in; the picker
    // only lets someone who already has the installers point at them so the
    // run stays offline.
    private var redistInstallerControls: some View {
        Section {
            Picker("Installer source", selection: $model.usesLocalInstallers) {
                Text("Download the installers automatically").tag(false)
                Text("Provide installers locally").tag(true)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            if model.usesLocalInstallers {
                HStack(spacing: 8) {
                    TextField("Installers folder",
                              text: $model.redistInstallerDirectory,
                              prompt: Text("Path to a folder with downloaded installers"))
                        .accessibilityLabel("Installers folder")
                    Button("Choose…") {
                        model.chooseRedistInstallerDirectory()
                    }
                    .accessibilityLabel("Choose installers folder")
                }
                ForEach(redistInstallerStatuses, id: \.installer.filename) { status in
                    Label {
                        LabeledContent(status.installer.title) {
                            Text(status.isPresent
                                 ? "Found locally; verified during setup"
                                 : "Will be downloaded (\(status.installer.sizeLabel))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: status.isPresent ? "checkmark.circle.fill" : "arrow.down.circle")
                            .foregroundStyle(status.isPresent ? SetupStatusTone.success.color : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text("Dependencies")
        }
        .task(id: model.usesLocalInstallers ? model.redistInstallerDirectory : "") {
            redistInstallerStatuses = RedistInstallers.statuses(
                userDirectory: model.usesLocalInstallers ? model.redistInstallerDirectory : ""
            )
        }
    }

    // MARK: - Advanced

    private var advancedControls: some View {
        Section {
            DisclosureGroup("Advanced options", isExpanded: $advancedIsOpen) {
                DisclosureBody {
                    driveMappingControls
                    Toggle(SetupOptionCopy.saveDetailedLog, isOn: $model.saveVerboseLog)
                }
            }
        }
    }

    // MARK: - Drive Mapping

    @ViewBuilder
    private var driveMappingControls: some View {
        LabeledContent("Drive root (G:)") {
            Text(model.configuration.optionalGDriveRoot)
                .textSelection(.enabled)
        }
        LabeledContent("Mac root (Z:)") {
            Text("/")
                .textSelection(.enabled)
        }
        SectionNote("G: uses the parent of the selected executable’s folder. Z: provides access to your Mac’s filesystem. Existing ModOrganizer paths must still point to the correct folders.")
    }
}
