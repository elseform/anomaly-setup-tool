import Foundation
import Observation

@MainActor
@Observable
final class LaunchController {
    private(set) var isLaunching = false
    var error: String?
    @ObservationIgnored private let spawn: (URL, URL, [String]) throws -> Void
    @ObservationIgnored private let terminate: () -> Void

    init(spawn: @escaping (URL, URL, [String]) throws -> Void = LaunchController.startProcess,
         terminate: @escaping () -> Void) {
        self.spawn = spawn
        self.terminate = terminate
    }

    func launch(_ entry: LaunchEntry, model: ConfiguratorModel) {
        guard !isLaunching else { return }
        isLaunching = true
        error = nil
        do {
            guard let wrapper = model.install.wrapperURL, let prefix = model.prefixURL else {
                throw LauncherError.message("Open this from an installed wrapper.")
            }
            _ = try LaunchTarget.resolve(model.path(for: entry.slot), prefix: prefix)
            let directory = model.runDirectory(for: entry.slot)
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
            // The helper runs EXE_PATH from app.env, so save the chosen slot there.
            model.activate(entry.slot)
            guard model.persist() else { throw LauncherError.message(model.saveError ?? "Could not save settings.") }
            try spawn(helper, logs.appendingPathComponent("launcher.log"), entry.arguments)
            terminate()
        } catch {
            self.error = error.localizedDescription
            isLaunching = false
        }
    }

    nonisolated static func startProcess(helper: URL, log: URL, arguments: [String] = []) throws {
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
        try process.run()
    }
}
