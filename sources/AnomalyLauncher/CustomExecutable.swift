import Foundation

/// A user-chosen Windows executable that gets its own tile. Stored in app.env
/// as numbered keys, written in list order with no gaps:
///   ANOMALY_CUSTOM_EXE_COUNT, ANOMALY_CUSTOM_EXE_<n>_PATH / _RUN_DIR / _NAME / _ARGS
struct CustomExecutable: Identifiable, Equatable {
    /// Lives only in memory, so a rename or removal never changes another row's identity.
    let id: UUID
    /// What the tile is called. Empty means the executable's file name.
    var name: String
    var path: String
    var runDirectory: String
    /// Startup arguments for this executable alone.
    var arguments: String

    init(id: UUID = UUID(), name: String = "", path: String, runDirectory: String, arguments: String = "") {
        self.id = id
        self.name = name
        self.path = path
        self.runDirectory = runDirectory
        self.arguments = arguments
    }

    var defaultName: String { Self.defaultName(forPath: path) }

    var label: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultName : trimmed
    }

    var macPath: String? { LaunchTarget.macPath(windowsPath: path, runDirectory: runDirectory) }

    static func defaultName(forPath path: String) -> String {
        (LaunchTarget.fileName(ofWindowsPath: path) as NSString).deletingPathExtension
    }
}

enum CustomExecutableStore {
    static let countKey = "ANOMALY_CUSTOM_EXE_COUNT"
    /// Keys written before several executables were allowed: one path, one directory.
    static let legacyPathKey = "ANOMALY_CUSTOM_EXE_PATH"
    static let legacyRunDirKey = "ANOMALY_CUSTOM_EXE_RUN_DIR"

    private static let prefix = "ANOMALY_CUSTOM_EXE_"

    /// Whether app.env keeps this key as an opaque line of the custom executable list.
    static func owns(_ key: String) -> Bool { key.hasPrefix(prefix) }

    static func key(_ index: Int, _ field: String) -> String { "\(prefix)\(index)_\(field)" }

    /// The numbered entries, in order. Entries without a path are dropped. An
    /// entry saved before each had its own arguments takes `defaultArguments`.
    static func load(from passthrough: [String: String], defaultArguments: String = "") -> [CustomExecutable] {
        let count = Int(unquote(passthrough[countKey] ?? "")) ?? 0
        guard count > 0 else { return [] }
        return (1...count).compactMap { index in
            let path = unquote(passthrough[key(index, "PATH")] ?? "")
            guard !path.isEmpty else { return nil }
            return CustomExecutable(
                name: unquote(passthrough[key(index, "NAME")] ?? ""),
                path: path,
                runDirectory: unquote(passthrough[key(index, "RUN_DIR")] ?? ""),
                arguments: passthrough[key(index, "ARGS")].map(unquote) ?? defaultArguments
            )
        }
    }

    /// Replaces every custom executable line with the list.
    static func store(_ executables: [CustomExecutable], into passthrough: inout [String: String]) {
        for existing in passthrough.keys where owns(existing) { passthrough[existing] = nil }
        passthrough[countKey] = shellQuote(String(executables.count))
        for (offset, executable) in executables.enumerated() {
            let index = offset + 1
            passthrough[key(index, "PATH")] = shellQuote(executable.path)
            passthrough[key(index, "RUN_DIR")] = shellQuote(executable.runDirectory)
            passthrough[key(index, "NAME")] = shellQuote(executable.name)
            passthrough[key(index, "ARGS")] = shellQuote(executable.arguments)
        }
    }
}
