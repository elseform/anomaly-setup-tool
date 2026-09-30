import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = ConfiguratorModel()
    let launcher = LaunchController()

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        !model.canEdit || model.persist() ? .terminateNow : .terminateCancel
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        !model.canEdit || model.persist()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct ConfiguratorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The id names the saved window frame. "launcher" belonged to the
        // single-column window, whose saved height fills the screen.
        Window(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Anomaly", id: "settings") {
            ConfiguratorView(model: appDelegate.model, launcher: appDelegate.launcher)
                .background(WindowCloseGuard(delegate: appDelegate))
        }
        .defaultSize(width: Layout.defaultWidth, height: Layout.defaultHeight)
        .windowResizability(.contentMinSize)
    }
}
