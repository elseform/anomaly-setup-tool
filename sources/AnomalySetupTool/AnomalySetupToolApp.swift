import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var quitReplySent = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Quitting while setup runs would leave the engine, Python and Wine going
    /// with a half-built wrapper, so confirm, then stop the engine and wait
    /// for it to remove its partial output before the app exits.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.isRunning else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Stop creating the wrapper?"
        alert.informativeText = "Setup is still running. Quitting now stops it and removes the unfinished wrapper."
        alert.addButton(withTitle: "Keep Going")
        alert.addButton(withTitle: "Stop and Quit")
        guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        model.engineDidExit = { [weak self] in self?.replyToTerminate() }
        model.interruptEngine()
        // Do not hang on quit if the engine never answers.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in self?.replyToTerminate() }
        return .terminateLater
    }

    private func replyToTerminate() {
        guard !quitReplySent else { return }
        quitReplySent = true
        NSApp.reply(toApplicationShouldTerminate: true)
    }
}

@main
struct AnomalySetupToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // A single window: the model is shared with the delegate, which needs
        // to know whether setup is running when the app quits.
        Window("Anomaly Setup Tool", id: "setup") {
            ContentView(model: appDelegate.model)
        }
        .windowResizability(.contentSize)
    }
}
