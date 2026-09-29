import SwiftUI
import AppKit

struct CreatePage: View {
    @Bindable var model: AppModel
    @Binding var createButtonSubmitted: Bool

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                if !model.installFailed {
                    Text(currentStageTitle)
                        .font(.headline)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                ProgressView(value: model.progress)
                    .accessibilityLabel("Wrapper creation progress")
            }

            Section {
                installStages
            }

            if model.installFailed {
                installFailureView
            }

            Section {
                DisclosureGroup("Show technical details", isExpanded: $model.showOutput) {
                    ScrollView {
                        Text(model.logText.isEmpty ? "No setup output is available yet." : model.logText)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 130)
                    .accessibilityLabel("Setup output")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var currentStageTitle: String {
        guard installStageRows.indices.contains(model.installStageIndex) else {
            return model.installStageCompletedIndex >= 0 ? "Almost done\u{2026}" : "Getting started\u{2026}"
        }
        return "\(installStageRows[model.installStageIndex].detail)\u{2026}"
    }

    // MARK: - Run Status

    @ViewBuilder
    private var installFailureView: some View {
        Section {
            Label("The wrapper couldn’t be created", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(SetupStatusTone.error.color)
            if model.savedLogPath.isEmpty {
                Text(model.saveVerboseLog
                     ? "The setup log location is unavailable. Copy the technical details below instead."
                     : "Saving the setup log was turned off. Copy the technical details below instead.")
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent("Log:") {
                    Button {
                        model.openSavedLog()
                    } label: {
                        Text(model.savedLogPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.link)
                    .help("Open log")
                }
            }
            LabeledContent {
                HStack(spacing: 12) {
                    Button("Copy details", action: model.copyLog)
                        .disabled(model.logText.isEmpty)
                    Link(SupportCopy.discordTitle, destination: SupportCopy.discordURL)
                        .help(SupportCopy.discordHelp)
                }
            } label: {
                RowLabel(title: "Press Try again, or ask for help in the GAMMA Discord and share the log.")
            }
        }
    }

    private var installStages: some View {
        ForEach(installStageRows, id: \.stage) { row in
            installStageRow(row: row)
        }
    }

    // Row numbers are indices into SetupEngineStage.allCases, the order a
    // run reaches them (dependencies, engine, prefix, driveMapping,
    // winetricks, wrapper, finalize).
    private var installStageRows: [(stage: Int, title: String, detail: String)] {
        [
            (0, "Preparing", "Finding the game engine"),
            (1, "Engine", "Unpacking the game engine"),
            (2, "Windows environment", "Preparing the Windows environment"),
            (3, "Drives", "Connecting your GAMMA folder"),
            (4, "Windows components", "Installing Windows components"),
            (5, "Wrapper", "Building the wrapper and its launcher"),
            (6, "Finishing", "Finishing up")
        ]
    }

    private func installStageRow(row: (stage: Int, title: String, detail: String)) -> some View {
        HStack(spacing: 8) {
            stageIcon(for: row.stage)
                .accessibilityHidden(true)
            Text(row.title)
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.detail.isEmpty ? row.title : "\(row.title), \(row.detail)")
        .accessibilityValue(stageStatus(for: row.stage))
    }

    private func stageStatus(for index: Int) -> String {
        if model.installFailed && index == model.installStageIndex { return "Failed" }
        if index <= model.installStageCompletedIndex { return "Completed" }
        if index == model.installStageIndex { return "In progress" }
        return "Pending"
    }

    private func stageIcon(for index: Int) -> some View {
        return Group {
            if model.installFailed && index == model.installStageIndex {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(SetupStatusTone.error.color)
            } else if index <= model.installStageCompletedIndex {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SetupStatusTone.success.color)
            } else if index == model.installStageIndex {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundStyle(.tint)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 18)
    }
}

struct CompletePage: View {
    let model: AppModel

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Label {
                    RowLabel(title: model.outputAppName, detail: model.outputAppPath, detailIsPath: true)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SetupStatusTone.success.color)
                }
                USVFSStatusRow(outcome: model.usvfsPlanForRun, finished: true)
            }

            Section("Next steps") {
                ForEach(nextSteps, id: \.number) { step in
                    Label {
                        Text(step.text)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "\(step.number).circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }

            Section {
                LabeledContent {
                    HStack(spacing: 12) {
                        Link(SupportCopy.discordTitle, destination: SupportCopy.discordURL)
                            .help(SupportCopy.discordHelp)
                        Link(SupportCopy.githubTitle, destination: SupportCopy.githubURL)
                            .help(SupportCopy.githubHelp)
                    }
                } label: {
                    RowLabel(title: "There may be some additional mods required for optimal in-game performance. Check Discord or GitHub for more info.")
                }
                if model.saveVerboseLog {
                    if model.savedLogPath.isEmpty {
                        Text("Setup log location unavailable")
                            .foregroundStyle(.secondary)
                    } else {
                        LabeledContent("Setup log") {
                            Button {
                                model.openSavedLog()
                            } label: {
                                Text(model.savedLogPath)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .buttonStyle(.link)
                            .help("Open setup log")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// The generated wrapper owns both settings and launching.
    private var nextSteps: [(number: Int, text: LocalizedStringKey)] {
        let launch: LocalizedStringKey = model.configuration.usesCustomLaunchExecutable
            ? "Press **Launch** to start **\(model.selectedLaunchExecutableLabel)**."
            : "Press **Launch** to open Mod Organizer, then **Run** there to start the game."
        return [
            (1, "Open **\(model.outputAppName)** from ~/Applications. Show in Finder below takes you there."),
            (2, launch),
        ]
    }
}
