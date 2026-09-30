import Foundation
import Observation

@MainActor
@Observable
final class LaunchController {
    /// The tile whose helper process is still running. The window stays open
    /// and locked until it exits.
    private(set) var running: LaunchEntry?
    var isRunning: Bool { running != nil }
    var error: String?
    /// Starts the helper and calls the last argument once it exits, from any thread.
    @ObservationIgnored private let spawn: (URL, URL, [String], @escaping @Sendable () -> Void) throws -> Void

    init(spawn: @escaping (URL, URL, [String], @escaping @Sendable () -> Void) throws -> Void = { helper, log, arguments, onExit in
        try LaunchController.startProcess(helper: helper, log: log, arguments: arguments, onExit: onExit)
    }) {
        self.spawn = spawn
    }

    func launch(_ entry: LaunchEntry, model: ConfiguratorModel) {
        guard !isRunning else { return }
        error = nil
        do {
            guard let wrapper = model.install.wrapperURL, let prefix = model.prefixURL else {
                throw LauncherError.message("Open this from an installed wrapper.")
            }
            let target = model.target(for: entry.source)
            _ = try LaunchTarget.resolve(target.path, prefix: prefix)
            let directory = target.runDirectory
            var isDirectory: ObjCBool = false
            guard !directory.isEmpty, FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw LauncherError.message("The executable’s working directory is missing. Choose the executable again.")
            }
            let helper = wrapper.appendingPathComponent("Contents/MacOS/launcher")
            let wine = wrapper.appendingPathComponent("Contents/Resources/engine/bin/wine")
            guard FileManager.default.isExecutableFile(atPath: helper.path), FileManager.default.isExecutableFile(atPath: wine.path) else {
                throw LauncherError.message("The wrapper’s launch helper or Wine executable is missing.")
            }
            let logs = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs")
                .appendingPathComponent(wrapper.deletingPathExtension().lastPathComponent)
            // The helper runs EXE_PATH from app.env, so save the chosen target there.
            model.activate(entry.source)
            guard model.persist() else { throw LauncherError.message(model.saveError ?? "Could not save settings.") }
            running = entry
            do {
                try spawn(helper, logs.appendingPathComponent("launcher.log"), entry.arguments) { [weak self] in
                    Task { @MainActor in self?.running = nil }
                }
            } catch {
                running = nil
                throw error
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    nonisolated static func startProcess(helper: URL, log: URL, arguments: [String] = [],
                                         onExit: @escaping @Sendable () -> Void = {}) throws {
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: log.path) {
            guard FileManager.default.createFile(atPath: log.path, contents: nil) else {
                throw LauncherError.message("Could not create launch log at \(log.path).")
            }
        }
        let output = try FileHandle(forWritingTo: log)
        defer { try? output.close() }
        try output.seekToEnd()
        let process = Process()
        process.executableURL = helper
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = output
        process.terminationHandler = { _ in onExit() }
        try process.run()
    }
}
