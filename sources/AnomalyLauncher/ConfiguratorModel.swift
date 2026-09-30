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
    @ObservationIgnored private var migratedSlots = false

    init(install: InstallLayout = .current()) {
        self.install = install
        if let paths = PathsConfig.load(install: install) {
            prefixURL = URL(fileURLWithPath: paths.winePrefix ?? URL(fileURLWithPath: paths.configFile).deletingLastPathComponent().appendingPathComponent("prefix").path)
            configFile = paths.configFile
            loadError = nil
            state = loadState(configFile: paths.configFile, legacyStateFile: paths.stateFile)
            migrateLaunchSlots()
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

    /// Wrappers made before the two-path split hold only EXE_PATH, the target
    /// picked at creation. It becomes the Mod Organizer path or the custom path
    /// by its file name, so the choice made at creation is kept.
    private func migrateLaunchSlots() {
        let slotKeys = [LaunchSlot.modOrganizer, .custom].flatMap { [$0.pathKey, $0.runDirKey] }
        guard !slotKeys.contains(where: { state.passthrough[$0] != nil }),
              let path = state.passthrough["EXE_PATH"], !unquote(path).isEmpty else { return }
        let slot: LaunchSlot = LaunchTarget.isModOrganizer(unquote(path)) ? .modOrganizer : .custom
        state.passthrough[slot.pathKey] = path
        state.passthrough[slot.runDirKey] = state.passthrough["EXE_RUN_DIR"]
        migratedSlots = true
    }

    func path(for slot: LaunchSlot) -> String { unquote(state.passthrough[slot.pathKey] ?? "") }

    func runDirectory(for slot: LaunchSlot) -> String { unquote(state.passthrough[slot.runDirKey] ?? "") }

    /// The launch grid: Mod Organizer and its Anomaly shortcuts while that path
    /// is set, then the custom executable while that path is set.
    var launchEntries: [LaunchEntry] {
        var entries: [LaunchEntry] = []
        if !path(for: .modOrganizer).isEmpty { entries += [.modOrganizer, .anomalyDX11, .anomalyDX11AVX] }
        if !path(for: .custom).isEmpty { entries.append(.custom(path: path(for: .custom))) }
        return entries
    }

    func selectTarget(_ url: URL, slot: LaunchSlot) {
        do {
            guard let prefixURL else { throw LauncherError.message("Wine prefix location is missing.") }
            let target = try LaunchTarget.select(url, prefix: prefixURL)
            if slot == .modOrganizer, !LaunchTarget.isModOrganizer(target.windowsPath) {
                throw LauncherError.message("Choose ModOrganizer.exe.")
            }
            state.passthrough[slot.pathKey] = shellQuote(target.windowsPath)
            state.passthrough[slot.runDirKey] = shellQuote(target.directory.path)
            persist()
        } catch { saveError = error.localizedDescription }
    }

    func clearTarget(_ slot: LaunchSlot) {
        state.passthrough[slot.pathKey] = shellQuote("")
        state.passthrough[slot.runDirKey] = shellQuote("")
        persist()
    }

    /// Makes the slot's executable the one the launch helper runs.
    func activate(_ slot: LaunchSlot) {
        state.passthrough["EXE_PATH"] = state.passthrough[slot.pathKey]
        state.passthrough["EXE_RUN_DIR"] = state.passthrough[slot.runDirKey]
    }

    @discardableResult
    func persist() -> Bool {
        do {
            guard canEdit else { throw LauncherError.message(loadError ?? "Settings location is missing.") }
            try saveEnv(&state, configFile: configFile)
            saveError = nil
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }
}
