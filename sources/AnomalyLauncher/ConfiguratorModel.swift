import Foundation
import Observation

@MainActor
@Observable
final class ConfiguratorModel {
    var state: ConfiguratorState
    var saveError: String?
    @ObservationIgnored let install: InstallLayout
    @ObservationIgnored let prefixURL: URL?
    /// Bumped by resetToDefaults so rows, which keep their own editing
    /// state, are rebuilt from the new values.
    private(set) var revision = 0
    @ObservationIgnored let configFile: String
    @ObservationIgnored let loadError: String?
    /// Executables that get their own tile, in the order the user added them.
    private(set) var customExecutables: [CustomExecutable] = []
    @ObservationIgnored private var migratedSlots = false

    init(install: InstallLayout = .current()) {
        self.install = install
        if let paths = PathsConfig.load(install: install) {
            prefixURL = URL(fileURLWithPath: paths.winePrefix ?? URL(fileURLWithPath: paths.configFile).deletingLastPathComponent().appendingPathComponent("prefix").path)
            configFile = paths.configFile
            loadError = nil
            state = loadState(configFile: paths.configFile, legacyStateFile: paths.stateFile)
            loadExecutables()
        } else {
            prefixURL = nil
            configFile = ""
            loadError = "Could not find this wrapper’s app.env. Open the installed Anomaly wrapper; settings cannot be saved."
            state = defaultState()
        }
        // D3DMetal is no longer offered; move installs that selected it to DXMT.
        if state.vars["ANOMALY_GRAPHICS_BACKEND"]?.value != "dxmt" {
            state.vars["ANOMALY_GRAPHICS_BACKEND"] = VarEntry(enabled: true, value: "dxmt")
            persist()
        }
        if migratedSlots { persist() }
    }

    var canEdit: Bool {
        loadError == nil
    }

    /// Puts every setting back to what a new install starts with. Launcher
    /// paths (passthrough keys) and lines the Configurator doesn't own are
    /// kept.
    func resetToDefaults() {
        let defaults = defaultState()
        state.vars = defaults.vars
        state.dxmtConfig = defaults.dxmtConfig
        revision += 1
        persist()
    }

    /// Whether an app.env on/off switch (bool "1" or retina "Y") is on.
    func isOn(_ key: String) -> Bool {
        guard let entry = schemaByKey[key] else { return false }
        let value = varEntry(for: entry).value.trimmingCharacters(in: .whitespaces)
        return value == "1" || value == "Y"
    }

    func isVisible(_ setting: SettingRef) -> Bool {
        guard let parent = shownOnlyWhenOn[setting.key] else { return true }
        return isOn(parent)
    }

    /// Settings in the category that differ from what a new install starts with.
    func changedCount(in category: SettingCategory) -> Int {
        category.groups.flatMap(\.settings).filter(isChanged).count
    }

    private func isChanged(_ setting: SettingRef) -> Bool {
        switch setting {
        case .env(let key):
            guard let entry = schemaByKey[key] else { return false }
            let current = varEntry(for: entry)
            if current.enabled != entry.enabledInNewInstall { return true }
            return current.enabled && current.value != entry.defaultValue
        case .dxmt(let key):
            guard let entry = dxmtConfigByKey[key] else { return false }
            let current = dxmtEntry(for: entry)
            if current.enabled != entry.enabledByDefault { return true }
            return current.enabled && current.value != entry.defaultValue
        }
    }

    func varEntry(for entry: SchemaEntry) -> VarEntry {
        state.vars[entry.key] ?? VarEntry(enabled: entry.enabledInNewInstall, value: entry.defaultValue)
    }

    func setVar(_ key: String, enabled: Bool, value: String, save: Bool = true) {
        state.vars[key] = VarEntry(enabled: enabled, value: value)
        if save { persist() }
    }

    func dxmtEntry(for entry: DXMTConfigEntry) -> VarEntry {
        state.dxmtConfig[entry.key] ?? VarEntry(enabled: entry.enabledByDefault, value: entry.defaultValue)
    }

    func setDXMT(_ key: String, enabled: Bool, value: String, save: Bool = true) {
        state.dxmtConfig[key] = VarEntry(enabled: enabled, value: value)
        if save { persist() }
    }

    private static let modOrganizerPathKey = "ANOMALY_MO2_EXE_PATH"
    private static let modOrganizerRunDirKey = "ANOMALY_MO2_EXE_RUN_DIR"

    /// Reads the custom executable list. Wrappers made before it existed hold
    /// either one custom path in the old unnumbered keys or only EXE_PATH, the
    /// target picked at creation; that becomes the Mod Organizer path or a
    /// custom executable by its file name, so the choice made at creation is
    /// kept. ANOMALY_CUSTOM_EXE_COUNT marks a file already in the current format.
    private func loadExecutables() {
        let passthrough = state.passthrough
        customExecutables = CustomExecutableStore.load(from: passthrough)
        let legacyKeys = [CustomExecutableStore.legacyPathKey, CustomExecutableStore.legacyRunDirKey]
        let hasLegacyCustom = legacyKeys.contains { passthrough[$0] != nil }
        if let path = passthrough[CustomExecutableStore.legacyPathKey].map(unquote), !path.isEmpty {
            customExecutables.insert(CustomExecutable(path: path, runDirectory: unquote(passthrough[CustomExecutableStore.legacyRunDirKey] ?? "")), at: 0)
        }
        for key in legacyKeys { state.passthrough[key] = nil }
        let isCurrent = passthrough[CustomExecutableStore.countKey] != nil
            || hasLegacyCustom || passthrough[Self.modOrganizerPathKey] != nil
        migratedSlots = hasLegacyCustom
        guard !isCurrent, let path = passthrough["EXE_PATH"].map(unquote), !path.isEmpty else { return }
        migratedSlots = true
        let runDirectory = passthrough["EXE_RUN_DIR"] ?? shellQuote("")
        if LaunchTarget.isModOrganizer(path) {
            state.passthrough[Self.modOrganizerPathKey] = passthrough["EXE_PATH"]
            state.passthrough[Self.modOrganizerRunDirKey] = runDirectory
        } else {
            customExecutables.append(CustomExecutable(path: path, runDirectory: unquote(runDirectory)))
        }
    }

    var modOrganizerPath: String { unquote(state.passthrough[Self.modOrganizerPathKey] ?? "") }

    var modOrganizerRunDirectory: String { unquote(state.passthrough[Self.modOrganizerRunDirKey] ?? "") }

    /// The saved path and working directory a tile starts.
    func target(for source: LaunchSource) -> (path: String, runDirectory: String) {
        switch source {
        case .modOrganizer:
            return (modOrganizerPath, modOrganizerRunDirectory)
        case .custom(let id):
            let executable = customExecutables.first { $0.id == id }
            return (executable?.path ?? "", executable?.runDirectory ?? "")
        }
    }

    /// Mod Organizer and its Anomaly shortcuts, while that path is set.
    var modOrganizerEntries: [LaunchEntry] {
        modOrganizerPath.isEmpty ? [] : [.modOrganizer, .anomalyDX11, .anomalyDX11AVX]
    }

    var customEntries: [LaunchEntry] { customExecutables.map(LaunchEntry.custom) }

    /// The launch grid: the Mod Organizer tiles, then one tile per custom executable.
    var launchEntries: [LaunchEntry] { modOrganizerEntries + customEntries }

    func selectModOrganizer(_ url: URL) {
        do {
            let target = try resolveTarget(url)
            guard LaunchTarget.isModOrganizer(target.windowsPath) else { throw LauncherError.message("Choose ModOrganizer.exe.") }
            state.passthrough[Self.modOrganizerPathKey] = shellQuote(target.windowsPath)
            state.passthrough[Self.modOrganizerRunDirKey] = shellQuote(target.directory.path)
            persist()
        } catch { saveError = error.localizedDescription }
    }

    func clearModOrganizer() {
        state.passthrough[Self.modOrganizerPathKey] = shellQuote("")
        state.passthrough[Self.modOrganizerRunDirKey] = shellQuote("")
        persist()
    }

    func addCustomExecutable(_ url: URL) {
        do {
            let target = try resolveTarget(url)
            customExecutables.append(CustomExecutable(path: target.windowsPath, runDirectory: target.directory.path))
            persist()
        } catch { saveError = error.localizedDescription }
    }

    func removeCustomExecutable(_ id: UUID) {
        customExecutables.removeAll { $0.id == id }
        persist()
    }

    /// An empty name goes back to the executable's file name.
    func setCustomName(_ id: UUID, _ name: String, save: Bool = true) {
        guard let index = customExecutables.firstIndex(where: { $0.id == id }) else { return }
        customExecutables[index].name = name
        if save { persist() }
    }

    private func resolveTarget(_ url: URL) throws -> LaunchTarget {
        guard let prefixURL else { throw LauncherError.message("Wine prefix location is missing.") }
        return try LaunchTarget.select(url, prefix: prefixURL)
    }

    /// Makes the tile's executable the one the launch helper runs.
    func activate(_ source: LaunchSource) {
        let target = target(for: source)
        state.passthrough["EXE_PATH"] = shellQuote(target.path)
        state.passthrough["EXE_RUN_DIR"] = shellQuote(target.runDirectory)
    }

    @discardableResult
    func persist() -> Bool {
        do {
            guard canEdit else { throw LauncherError.message(loadError ?? "Settings location is missing.") }
            CustomExecutableStore.store(customExecutables, into: &state.passthrough)
            try saveEnv(&state, configFile: configFile)
            saveError = nil
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }
}
