import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
import AnomalySetupCore
#endif

extension AppModel {
    // MARK: - Configuration

    var configuration: SetupConfiguration {
        SetupConfiguration(
            appName: appName,
            installDirectory: installDirectory,
            customLaunchExecutablePath: customLaunchExecutablePath,
            saveVerboseLog: saveVerboseLog,
            manualModOrganizerPath: manualModOrganizerPath
        )
    }

    var engineURL: URL {
        if let bundled = AppResources.bundle.url(forResource: "anomaly-setup-engine", withExtension: nil) {
            return bundled
        }
        if let bundled = Bundle.main.url(forResource: "anomaly-setup-engine", withExtension: nil) {
            return bundled
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let builtEngine = cwd.appendingPathComponent("dist/intermediates/anomaly-setup-engine")
        if FileManager.default.isExecutableFile(atPath: builtEngine.path) {
            return builtEngine
        }
        return cwd.appendingPathComponent("anomaly-setup-engine")
    }

    var outputAppPath: String {
        SetupConfiguration(appName: appName, installDirectory: installDirectory).outputAppPath
    }

    /// "<name>", as Finder shows the created app (without ".app").
    var outputAppName: String {
        URL(fileURLWithPath: outputAppPath).deletingPathExtension().lastPathComponent
    }

    var wrapperNameIsValid: Bool {
        configuration.wrapperNameIsValid && !FileManager.default.fileExists(atPath: outputAppPath)
    }

    var outputAppAlreadyExists: Bool {
        configuration.wrapperNameIsValid && FileManager.default.fileExists(atPath: outputAppPath)
    }

    var wrapperNameValidationMessage: String {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Enter a wrapper name."
        }
        if !SetupConfiguration.isValidWrapperName(appName) {
            return "Use a name without / or : characters."
        }
        if FileManager.default.fileExists(atPath: outputAppPath) {
            return "A wrapper with this name already exists."
        }
        return ""
    }

    /// The local engine archive setup will use, or nil to download the newest
    /// published anomaly-wine-engine release (see WineEngineSetup.resolveArchive).
    /// A local archive is used as is.
    var localEngineArchivePath: String? {
        guard usesLocalEngine else { return nil }
        let path = wineEngineArchivePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    var setupReady: Bool {
        selectedLaunchExecutableFound && wrapperNameIsValid && (!usesLocalEngine || localEngineArchivePath != nil)
    }

    var selectedLaunchExecutablePath: String {
        configuration.selectedLaunchExecutablePath
    }

    var selectedLaunchExecutableLabel: String {
        configuration.selectedLaunchExecutableLabel
    }

    var selectedLaunchExecutableFound: Bool {
        configuration.selectedLaunchExecutableFound
    }

    var createHeaderTitle: String {
        installFailed ? "Something went wrong" : "Creating the wrapper"
    }

    var createHeaderSubtitle: String {
        if installFailed {
            return "Setup stopped before the wrapper was finished."
        }
        return "This takes a few minutes."
    }

    var plannedWineDriveMapping: String {
        configuration.plannedWineDriveMapping
    }
}
