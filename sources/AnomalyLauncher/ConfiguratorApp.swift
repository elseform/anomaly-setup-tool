import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = ConfiguratorModel()
    let launcher = LaunchController()
    /// Set once the user chose to leave without saving, so quitting after the
    /// window closes does not ask again.
    private var discardedUnsavedChanges = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        canLeave(action: "Quit") ? .terminateNow : .terminateCancel
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        canLeave(action: "Close")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Saves the settings. When that fails the user can stay and fix the problem
    /// or leave and lose the unsaved changes; a window that can never close
    /// would leave force-quitting as the only way out.
    private func canLeave(action: String) -> Bool {
        guard model.canEdit, !discardedUnsavedChanges, !model.persist() else { return true }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Settings could not be saved"
        alert.informativeText = "\(model.saveError ?? "The settings file could not be written.")\n\nStay to fix it, or discard the unsaved changes."
        alert.addButton(withTitle: "Stay")
        alert.addButton(withTitle: "Discard and \(action)")
        guard alert.runModal() == .alertSecondButtonReturn else { return false }
        discardedUnsavedChanges = true
        return true
    }
}

@main
struct ConfiguratorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The id names the saved window frame. "launcher" belonged to the
        // single-column window, whose saved height fills the screen.
        Window(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Anomaly", id: "settings") {
            ConfiguratorView(model: appDelegate.model, launcher: appDelegate.launcher)
                .background(WindowCloseGuard(shouldClose: { appDelegate.windowShouldClose($0) }))
        }
        .defaultSize(width: Layout.defaultWidth, height: Layout.defaultHeight)
        .windowResizability(.contentMinSize)
    }
}
