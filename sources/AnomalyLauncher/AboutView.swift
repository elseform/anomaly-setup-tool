import SwiftUI

/// Versions of the launcher, the engine and DXMT inside this wrapper.
struct AboutView: View {
    let model: ConfiguratorModel
    let isLocked: Bool
    private let engine: EngineInfo?
    @State private var confirmReset = false

    init(model: ConfiguratorModel, isLocked: Bool) {
        self.model = model
        self.isLocked = isLocked
        engine = EngineInfo.load(install: model.install)
    }

    var body: some View {
        Form {
            Section("Launcher") {
                row("Version", BuildInfo.version)
            }
            Section("Engine") {
                row("Version", engine?.versionLabel, link: engine?.releaseURL)
                row("Build", engine?.buildNumber.map(String.init))
                row("Wine", engine?.base?.wine)
            }
            Section("DXMT") {
                row("Release", engine?.dxmt?.tag, link: engine?.dxmt?.releaseURL)
                row("Commit", engine?.dxmt?.shortCommit)
            }
            Section {
                Button("Reset to Defaults…", role: .destructive) { confirmReset = true }
                    .disabled(isLocked)
                    .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmReset) {
                        Button("Reset", role: .destructive, action: model.resetToDefaults)
                    } message: {
                        Text("Every setting, including startup arguments, goes back to what a new wrapper starts with.")
                    }
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ title: String, _ value: String?, link: URL? = nil) -> some View {
        LabeledContent(title) {
            if let value, let link {
                Link(value, destination: link)
                    .help("Open this release on GitHub")
            } else {
                Text(value ?? "Unknown")
                    .foregroundStyle(value == nil ? .secondary : .primary)
                    .textSelection(.enabled)
            }
        }
    }
}
