import SwiftUI

/// Versions of the launcher, the engine and DXMT inside this wrapper.
struct AboutView: View {
    private let engine: EngineInfo?

    init(install: InstallLayout) {
        engine = EngineInfo.load(install: install)
    }

    var body: some View {
        Form {
            Section("Launcher") {
                row("Version", BuildInfo.version)
            }
            Section("Engine") {
                row("Version", engine?.versionLabel)
                row("Build", engine?.buildNumber.map(String.init))
                row("Wine", engine?.base?.wine)
                row("CrossOver", engine?.base?.crossover)
            }
            Section("DXMT") {
                row("Release", engine?.dxmt?.tag)
                row("Commit", engine?.dxmt?.shortCommit)
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ title: String, _ value: String?) -> some View {
        LabeledContent(title) {
            Text(value ?? "Unknown")
                .foregroundStyle(value == nil ? .secondary : .primary)
                .textSelection(.enabled)
        }
    }
}
