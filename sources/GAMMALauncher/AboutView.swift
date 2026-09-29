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
                row("Version", engine?.versionLabel, link: engine?.releaseURL)
                row("Build", engine?.buildNumber.map(String.init))
                row("Wine", engine?.base?.wine)
            }
            Section("DXMT") {
                row("Release", engine?.dxmt?.tag, link: engine?.dxmt?.releaseURL)
                row("Commit", engine?.dxmt?.shortCommit)
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
