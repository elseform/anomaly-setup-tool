import Foundation

struct SetupConfiguration {
    static let defaultInstallDirectory = AppSettingsStore.defaultInstallDirectory
    var appName = "stalker-anomaly"
    var installDirectory = SetupConfiguration.defaultInstallDirectory
    /// A Windows executable chosen instead of ModOrganizer.exe; nil launches
    /// through MO2.
    var customLaunchExecutablePath: String?
    var saveVerboseLog = true
    var manualModOrganizerPath = ""

    var outputAppPath: String {
        URL(fileURLWithPath: installDirectory)
            .appendingPathComponent("\(Self.bundleName(forAppName: appName)).app").path
    }

    var wrapperNameIsValid: Bool {
        Self.isValidWrapperName(appName)
    }

    /// The name the .app is saved under: trimmed, without a ".app" suffix.
    /// The engine receives this form so it creates the path shown to the user.
    static func bundleName(forAppName name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix(".app") ? String(trimmed.dropLast(4)) : trimmed
    }

    static func isValidWrapperName(_ name: String) -> Bool {
        let bundleName = bundleName(forAppName: name)
        guard !bundleName.isEmpty else { return false }
        guard bundleName != "." && bundleName != ".." else { return false }
        return bundleName.rangeOfCharacter(from: CharacterSet(charactersIn: "/:")) == nil
    }

    /// The wrapper name suggested for a launch executable: "Anomaly" for
    /// ModOrganizer.exe, otherwise the executable's own name.
    static func defaultAppName(forLaunchExecutable path: String) -> String {
        let stem = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        return stem.caseInsensitiveCompare("ModOrganizer") == .orderedSame ? "Anomaly" : stem
    }

    var usesCustomLaunchExecutable: Bool {
        customLaunchExecutablePath != nil
    }

    var selectedLaunchExecutablePath: String {
        if let customLaunchExecutablePath {
            return customLaunchExecutablePath
        }
        let manualPath = manualModOrganizerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return manualPath.isEmpty ? "ModOrganizer.exe" : manualPath
    }

    var selectedLaunchExecutableLabel: String {
        usesCustomLaunchExecutable
            ? URL(fileURLWithPath: selectedLaunchExecutablePath).lastPathComponent
            : "ModOrganizer"
    }

    /// Whether a launch target is properly selected: MO2 by default, or a
    /// custom executable that exists. Every readiness gate in the app reads
    /// this.
    var selectedLaunchExecutableFound: Bool {
        if !usesCustomLaunchExecutable {
            return AppSettingsStore.isValidModOrganizerExecutable(selectedLaunchExecutablePath)
        }
        let path = selectedLaunchExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(fileURLWithPath: path).pathExtension.caseInsensitiveCompare("exe") == .orderedSame
            && FileManager.default.fileExists(atPath: path)
    }

    // anomaly-wine-engine's interactive_setup.py always mounts both Z:
    // (host root) and G: (the resolved flat-install root) unconditionally
    // — there is no drive-mapping mode choice for this pipeline.
    var plannedWineDriveMapping: String {
        optionalGDriveRoot.isEmpty ? "Z: -> /" : "G: -> \(optionalGDriveRoot)"
    }

    /// The G: root: two components above the launch target (MO2's own
    /// folder, then its parent), empty until a target is found.
    var optionalGDriveRoot: String {
        guard selectedLaunchExecutableFound else { return "" }
        return URL(fileURLWithPath: selectedLaunchExecutablePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .standardizedFileURL.path
    }
}
