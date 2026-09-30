import Foundation

@main
struct LauncherTests {
    @MainActor
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("anomaly-launcher-tests-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        func check(_ condition: Bool, _ message: String) {
            if !condition { fatalError(message) }
        }
        let literals = ["G:\\A B\\O'Brien.exe", "quotes \" $HOME `id` $(id) \\ end", "", "semi;colon", "Unicode Ж"]
        for value in literals { check(unquote(shellQuote(value)) == value, "shell literal round trip: \(value)") }
        let shown = SettingCategory.allCases.flatMap(\.groups).flatMap(\.settings).map(\.key)
        let expected = schema.map(\.key).filter { $0 != "ANOMALY_GRAPHICS_BACKEND" } + dxmtConfigKeys.map(\.key)
        check(shown.count == Set(shown).count, "every setting is listed once")
        check(Set(shown) == Set(expected), "every setting has a category")
        check(SettingCategory.about.groups.isEmpty && SettingCategory.about.sidebarSection == .info, "About lists no settings")
        check(SettingCategory.play.groups.isEmpty && SettingCategory.play.sidebarSection == .home, "launch grid lists no settings")
        check(SettingCategory.allCases.first == .play && SettingCategory.launchOptions.title == "Launch options", "grid comes first")
        let manifest = #"{"versionLabel":"CX26-W11-ANOMALY","buildNumber":19,"engineId":"cx26-w11-anomaly","base":{"crossover":"26.3.0","wine":"11.16"},"dxmt":{"tag":"anomaly-2026.09.27.1","commit":"fc8c94702375f19f5161fc970a251aecdfc5d4de"}}"#
        let info = try JSONDecoder().decode(EngineInfo.self, from: Data(manifest.utf8))
        check(info.versionLabel == "CX26-W11-ANOMALY" && info.buildNumber == 19, "engine label and build")
        check(info.base?.wine == "11.16", "engine wine version")
        check(info.releaseURL?.absoluteString == "https://github.com/elseform/anomaly-wine-engine/releases/tag/engine-cx26-w11-anomaly-19", "engine release link")
        check(info.dxmt?.releaseURL?.absoluteString == "https://github.com/elseform/dxmt/releases/tag/anomaly-2026.09.27.1", "dxmt release link")
        check(info.dxmt?.tag == "anomaly-2026.09.27.1" && info.dxmt?.shortCommit == "fc8c947", "dxmt tag and short commit")
        check(try JSONDecoder().decode(EngineInfo.self, from: Data("{}".utf8)).dxmt == nil, "manifest without dxmt still decodes")
        let wrapper = root.appendingPathComponent("Test.app")
        let resources = wrapper.appendingPathComponent("Contents/Resources")
        let helper = wrapper.appendingPathComponent("Contents/MacOS/launcher")
        let wine = resources.appendingPathComponent("engine/bin/wine")
        let support = root.appendingPathComponent("support")
        let prefix = support.appendingPathComponent("prefix")
        let game = root.appendingPathComponent("game")
        for dir in [resources, helper.deletingLastPathComponent(), wine.deletingLastPathComponent(), prefix.appendingPathComponent("dosdevices"), game] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try fm.createSymbolicLink(at: prefix.appendingPathComponent("dosdevices/g:"), withDestinationURL: game)
        try fm.createSymbolicLink(at: prefix.appendingPathComponent("dosdevices/z:"), withDestinationURL: URL(fileURLWithPath: "/"))
        for file in [helper, wine] {
            try "#!/bin/sh\nexit 0\n".write(to: file, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
        let exe = game.appendingPathComponent("O'Brien.exe")
        let mo2 = root.appendingPathComponent("MODORGANIZER.EXE")
        for file in [exe, mo2] { try Data().write(to: file) }
        let selected = try LaunchTarget.select(exe, prefix: prefix)
        check(selected.windowsPath == "G:\\O'Brien.exe", "prefer G mapping")
        let external = try LaunchTarget.select(mo2, prefix: prefix)
        check(external.windowsPath.hasPrefix("Z:\\"), "external target uses Z")
        check(LaunchTarget.isModOrganizer(external.windowsPath), "case-insensitive MO2 detection")
        check(try LaunchTarget.resolve(selected.windowsPath, prefix: prefix) == exe, "resolve existing target")
        let config = support.appendingPathComponent("app.env")
        try JSONSerialization.data(withJSONObject: ["configFile": config.path, "winePrefix": prefix.path]).write(to: resources.appendingPathComponent("configurator-paths.json"))
        try "export EXE_PATH='G:\\mo2\\ModOrganizer.exe'\nexport EXE_RUN_DIR='/tmp/mo2'\nexport DXMT_CONFIG=\"d3d11.sampleNaNToZero=true;\"\n".write(to: config, atomically: true, encoding: .utf8)
        let legacy = ConfiguratorModel(install: InstallLayout(wrapperURL: wrapper))
        check(legacy.path(for: .modOrganizer) == "G:\\mo2\\ModOrganizer.exe" && legacy.runDirectory(for: .modOrganizer) == "/tmp/mo2", "legacy MO2 target becomes the MO2 path")
        check(legacy.path(for: .custom).isEmpty, "legacy MO2 target leaves custom unset")
        check(legacy.launchEntries.map(\.kind) == [.modOrganizer, .anomalyDX11, .anomalyDX11AVX], "MO2 path shows MO2 and Anomaly tiles")
        check(ConfiguratorModel(install: InstallLayout(wrapperURL: wrapper)).path(for: .modOrganizer) == legacy.path(for: .modOrganizer), "migration saved")
        try "export EXE_PATH='G:\\anomaly\\bin\\AnomalyDX11.exe'\nexport EXE_RUN_DIR='/tmp/bin'\n".write(to: config, atomically: true, encoding: .utf8)
        let legacyCustom = ConfiguratorModel(install: InstallLayout(wrapperURL: wrapper))
        check(legacyCustom.path(for: .custom) == "G:\\anomaly\\bin\\AnomalyDX11.exe" && legacyCustom.path(for: .modOrganizer).isEmpty, "legacy custom target becomes the custom path")
        check(legacyCustom.launchEntries.map(\.label) == ["AnomalyDX11"], "custom path shows only the custom tile")
        try "export DXMT_CONFIG=\"d3d11.sampleNaNToZero=true;\"\n".write(to: config, atomically: true, encoding: .utf8)
        let model = ConfiguratorModel(install: InstallLayout(wrapperURL: wrapper))
        check(model.launchEntries.isEmpty, "no paths, no tiles")
        check(model.state.dxmtConfig["d3d11.sampleNaNToZero"]?.enabled == true, "fresh seed displays NaN clamp On")
        check(model.state.vars["DXMT_REORDER_BLITS"]?.enabled == false, "existing app.env without the line keeps blit merging off")
        model.selectTarget(exe, slot: .custom)
        for value in literals {
            model.setVar("DEFAULT_GAME_ARGS", enabled: true, value: value)
            check(loadState(configFile: config.path).vars["DEFAULT_GAME_ARGS"]?.value == value, "env round trip")
        }
        try "export CUSTOM_KEEP='value'\n".write(to: config, atomically: true, encoding: .utf8)
        check(model.persist(), "save")
        check(try String(contentsOf: config, encoding: .utf8).contains("CUSTOM_KEEP"), "foreign line preserved")
        model.setVar("DEFAULT_GAME_ARGS", enabled: true, value: "-dbg")
        model.selectTarget(exe, slot: .modOrganizer)
        check(model.path(for: .modOrganizer).isEmpty && model.saveError != nil, "MO2 slot rejects other executables")
        model.selectTarget(mo2, slot: .modOrganizer)
        check(model.path(for: .modOrganizer) == external.windowsPath && model.path(for: .custom) == selected.windowsPath, "two paths kept apart")
        check(model.launchEntries.map(\.kind) == [.modOrganizer, .anomalyDX11, .anomalyDX11AVX, .custom], "both paths show all tiles, custom last")
        check(model.launchEntries.last?.label == "O'Brien", "custom tile is named after the executable")
        check(model.launchEntries[1].arguments == ["moshortcut://Anomaly (DX11)"] && model.launchEntries[2].arguments == ["moshortcut://Anomaly (DX11-AVX)"], "Anomaly tiles are MO2 shortcuts")
        check(model.state.vars["DEFAULT_GAME_ARGS"]?.value == "-dbg", "paths keep args")
        model.clearTarget(.modOrganizer)
        check(model.launchEntries.map(\.kind) == [.custom] && loadState(configFile: config.path).passthrough["ANOMALY_MO2_EXE_PATH"] == "''", "clearing MO2 hides its tiles and stays cleared")
        model.selectTarget(mo2, slot: .modOrganizer)
        model.resetToDefaults()
        check(model.path(for: .custom) == selected.windowsPath && model.path(for: .modOrganizer) == external.windowsPath, "reset preserves paths")
        check(model.state.vars["DXMT_REORDER_BLITS"] != nil, "transferred uncommitted setting")
        check(model.state.dxmtConfig["d3d11.releaseShaderIR"] != nil, "transferred shader setting")
        check(model.state.vars["DXMT_REORDER_BLITS"]?.enabled == true && model.isOn("DXMT_REORDER_BLITS"), "defaults merge blits")
        check(model.state.dxmtConfig["d3d11.releaseShaderIR"]?.enabled == true && model.state.dxmtConfig["d3d11.releaseShaderIR"]?.value == "true", "defaults release shader IR")
        check(model.state.dxmtConfig["dxgi.forceSDR"]?.enabled == true && model.state.dxmtConfig["dxgi.forceSDR"]?.value == "true", "defaults force SDR")
        check(!model.isOn("MTL_HUD_ENABLED") && !model.isOn("DXMT_FRAME_LIMITER"), "defaults keep HUD and limiter off")
        check(!model.isOn("MTL_CAPTURE_ENABLED") && !model.isOn("MTL_DEBUG_LAYER") && !model.isOn("MTL_SHADER_VALIDATION"), "defaults keep Metal debugging off")
        check(!model.isVisible(.env("DXMT_CAPTURE_EXECUTABLE")) && !model.isVisible(.env("DXMT_CAPTURE_FRAME")), "capture targets hidden while capture is off")
        model.setVar("MTL_CAPTURE_ENABLED", enabled: true, value: "1")
        check(model.isVisible(.env("DXMT_CAPTURE_EXECUTABLE")) && model.isVisible(.env("DXMT_CAPTURE_FRAME")), "capture targets shown once capture is on")
        check(loadState(configFile: config.path).vars["MTL_CAPTURE_ENABLED"]?.enabled == true, "capture switch saved to app.env")
        check(SettingCategory.debugging.groups.contains { $0.title == "Metal: Debug" && $0.settings.contains(.env("MTL_HUD_ENABLED")) }, "Metal: Debug group holds the HUD")
        model.setVar("MTL_CAPTURE_ENABLED", enabled: false, value: "0")
        check(model.state.dxmtConfig["d3d11.preferredMaxFrameRate"]?.enabled == false, "defaults leave frame cap off")
        var starts = 0
        var spawned: [[String]] = []
        var finish: (@Sendable () -> Void)?
        let launcher = LaunchController(spawn: { _, _, arguments, onExit in
            let saved = loadState(configFile: config.path)
            check(saved.vars["DEFAULT_GAME_ARGS"]?.value == "-pending", "flush before launch")
            check(unquote(saved.passthrough["EXE_PATH"] ?? "") == selected.windowsPath, "custom launch activates the custom path")
            spawned.append(arguments)
            starts += 1
            finish = onExit
        })
        model.setVar("DEFAULT_GAME_ARGS", enabled: true, value: "-pending", save: false)
        launcher.launch(.custom(path: model.path(for: .custom)), model: model)
        launcher.launch(.custom(path: model.path(for: .custom)), model: model)
        check(starts == 1 && spawned == [[]], "single launch without arguments")
        check(launcher.isRunning && launcher.running?.kind == .custom, "locked while the program runs")
        finish?()
        for _ in 0..<100 where launcher.isRunning { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        check(!launcher.isRunning && launcher.running == nil, "unlocks when the program exits")
        let shortcut = LaunchController(spawn: { _, _, arguments, _ in
            let saved = loadState(configFile: config.path)
            check(unquote(saved.passthrough["EXE_PATH"] ?? "") == external.windowsPath, "shortcut launch activates the MO2 path")
            check(arguments == ["moshortcut://Anomaly (DX11-AVX)"], "shortcut argument")
        })
        shortcut.launch(.anomalyDX11AVX, model: model)
        check(shortcut.error == nil, "shortcut launch succeeds: \(shortcut.error ?? "")")
        let failing = LaunchController(spawn: { _, _, _, _ in throw LauncherError.message("spawn failed") })
        failing.launch(.custom(path: model.path(for: .custom)), model: model)
        check(failing.error == "spawn failed" && !failing.isRunning, "recover spawn failure")
        try fm.removeItem(at: config)
        try fm.createDirectory(at: config, withIntermediateDirectories: false)
        let blocked = LaunchController(spawn: { _, _, _, _ in fatalError("must not spawn") })
        blocked.launch(.custom(path: model.path(for: .custom)), model: model)
        check(model.saveError != nil && blocked.error != nil, "save failure blocks launch")
        try fm.removeItem(at: config)
        model.selectTarget(exe, slot: .custom)
        try fm.removeItem(at: exe)
        blocked.launch(.custom(path: model.path(for: .custom)), model: model)
        check(blocked.error != nil, "missing target blocks launch")
        model.setVar("DEFAULT_GAME_ARGS", enabled: true, value: "bad\nline", save: false)
        check(!model.persist(), "reject multiline shell value")
        // The spawned helper runs on its own and reports when it exits.
        let witness = root.appendingPathComponent("child-survived")
        let child = root.appendingPathComponent("child-helper")
        try "#!/bin/sh\nsleep 0.2\nprintf survived > \(shellQuote(witness.path))\n".write(to: child, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: child.path)
        try LaunchController.startProcess(helper: child, log: root.appendingPathComponent("child.log"), onExit: {})
        let deadline = Date().addingTimeInterval(3)
        while !fm.fileExists(atPath: witness.path) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        check(fm.fileExists(atPath: witness.path), "child runs to completion")
        print("Launcher model and launch tests passed")
    }
}
