import SwiftUI

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct SetupPage: View {
    @Bindable var model: AppModel

    /// The one open disclosure. Only one opens at a time so the page always
    /// fits the fixed window.
    private enum Panel { case localEngine, redistInstallers, advanced }
    @State private var openPanel: Panel?
    @State private var redistInstallerStatuses: [RedistInstallers.Status] = []

    // MARK: - Body

    var body: some View {
        let ready = model.selectedLaunchExecutableFound && !model.isRunning
        Form {
            summary
            Group {
                engineArchiveControls
                redistInstallerControls
                advancedControls
            }
            .disabled(!ready)
            .opacity(ready ? 1 : 0.45)
        }
        .pageForm()
        .task(id: model.selectedLaunchExecutablePath) {
            model.refreshUSVFSPlan()
        }
    }

    private func isOpen(_ panel: Panel) -> Binding<Bool> {
        Binding(get: { openPanel == panel }, set: { openPanel = $0 ? panel : nil })
    }

    // MARK: - Summary

    private var summary: some View {
        Section {
            Label {
                Text("Create **\(model.outputAppName)** in ~/Applications")
            } icon: {
                Image(systemName: "app.badge.checkmark")
                    .foregroundStyle(.tint)
            }
            Label {
                Text(model.wineEngineArchivePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                     ? "Download the latest wine engine"
                     : "Use the local wine engine archive")
            } icon: {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.tint)
            }
            Label {
                Text("Set up the wrapper for \(model.selectedLaunchExecutableLabel)")
            } icon: {
                Image(systemName: "play.circle")
                    .foregroundStyle(.tint)
            }
            USVFSStatusRow(outcome: model.usvfsPlan)
        } header: {
            Text("What setup will do")
        }
    }

    // MARK: - Engine archive

    // Left empty (the default), the
    // newest published gamma-wine-engine release is resolved and downloaded
    // automatically; a path here is a local archive, used as is.
    private var engineArchiveControls: some View {
        Section {
            Text(model.wineEngineArchivePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? "Downloads the latest release from GitHub."
                 : "Uses your local engine archive as it is.")
                .foregroundStyle(.secondary)
            DisclosureGroup("Use a local engine archive instead", isExpanded: isOpen(.localEngine)) {
                DisclosureBody {
                    HStack(spacing: 8) {
                        TextField("Engine archive", text: $model.wineEngineArchivePath, prompt: Text("Automatic download"))
                            .accessibilityLabel("Engine archive")
                        Button("Choose…") {
                            model.chooseWineEngineArchive()
                        }
                        .accessibilityLabel("Choose engine archive")
                    }
                    SectionNote("Choose a .tar.xz engine archive.")
                    if !model.wineEngineArchivePath.isEmpty {
                        Button("Use automatic download") {
                            model.wineEngineArchivePath = ""
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            .onAppear {
                if !model.wineEngineArchivePath.isEmpty {
                    openPanel = .localEngine
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
    // run stays offline. Collapsed by default, since the default path needs
    // no decision.
    private var redistInstallerControls: some View {
        Section {
            DisclosureGroup(isExpanded: isOpen(.redistInstallers)) {
                DisclosureBody {
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
                    HStack(spacing: 8) {
                        TextField("Optional folder with downloaded installers",
                                  text: $model.redistInstallerDirectory)
                            .accessibilityLabel("Downloaded installers folder")
                        Button("Choose…") {
                            model.chooseRedistInstallerDirectory()
                        }
                        .accessibilityLabel("Choose downloaded installers folder")
                    }
                    SectionNote("Setup verifies every file against the engine’s required checksum. Missing files are downloaded automatically.")
                }
            } label: {
                Text("Downloaded automatically")
            }
        } header: {
            Text("Dependencies")
        }
        .task(id: model.redistInstallerDirectory) {
            redistInstallerStatuses = RedistInstallers.statuses(
                userDirectory: model.redistInstallerDirectory
            )
        }
    }

    // MARK: - Advanced

    private var advancedControls: some View {
        Section {
            DisclosureGroup("Show advanced options", isExpanded: isOpen(.advanced)) {
                DisclosureBody {
                    driveMappingControls
                    Toggle(SetupOptionCopy.saveDetailedLog, isOn: $model.saveVerboseLog)
                }
            }
        } header: {
            Text("Advanced")
        }
    }

    // MARK: - Drive Mapping

    @ViewBuilder
    private var driveMappingControls: some View {
        LabeledContent("Game root (G:)") {
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
