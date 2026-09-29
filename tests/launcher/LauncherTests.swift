import Foundation

@main
struct LauncherTests {
    @MainActor
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("gamma-launcher-tests-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        func check(_ condition: Bool, _ message: String) {
            if !condition { fatalError(message) }
        }
        let literals = ["G:\\A B\\O'Brien.exe", "quotes \" $HOME `id` $(id) \\ end", "", "semi;colon", "Unicode Ж"]
        for value in literals { check(unquote(shellQuote(value)) == value, "shell literal round trip: \(value)") }
        let shown = SettingCategory.allCases.flatMap(\.groups).flatMap(\.settings).map(\.key)
        let expected = schema.map(\.key).filter { $0 != "GAMMA_GRAPHICS_BACKEND" } + dxmtConfigKeys.map(\.key)
        check(shown.count == Set(shown).count, "every setting is listed once")
        check(Set(shown) == Set(expected), "every setting has a category")
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
        try "export DXMT_CONFIG=\"d3d11.sampleNaNToZero=true;\"\n".write(to: config, atomically: true, encoding: .utf8)
        let model = ConfiguratorModel(install: InstallLayout(wrapperURL: wrapper))
        check(model.state.dxmtConfig["d3d11.sampleNaNToZero"]?.enabled == true, "fresh seed displays NaN clamp On")
        check(model.state.vars["DXMT_REORDER_BLITS"]?.enabled == false, "existing app.env without the line keeps blit merging off")
        model.selectTarget(exe)
        for value in literals {
            model.setVar("DEFAULT_GAME_ARGS", enabled: true, value: value)
            check(loadState(configFile: config.path).vars["DEFAULT_GAME_ARGS"]?.value == value, "env round trip")
        }
        try "export CUSTOM_KEEP='value'\n".write(to: config, atomically: true, encoding: .utf8)
        check(model.persist(), "save")
        check(try String(contentsOf: config, encoding: .utf8).contains("CUSTOM_KEEP"), "foreign line preserved")
        model.setVar("DEFAULT_GAME_ARGS", enabled: true, value: "-dbg")
        model.selectTarget(mo2)
        check(model.isModOrganizer, "model detects MO2")
        check(model.state.vars["DEFAULT_GAME_ARGS"]?.value == "-dbg", "switch keeps args")
        model.selectTarget(exe)
        check(!model.isModOrganizer, "switch restores game args")
        model.resetToDefaults()
        check(model.targetPath == selected.windowsPath, "reset preserves target")
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
        var exits = 0
        let launcher = LaunchController(spawn: { _, _ in
            check(loadState(configFile: config.path).vars["DEFAULT_GAME_ARGS"]?.value == "-pending", "flush before launch")
            starts += 1
        }, terminate: { exits += 1 })
        model.setVar("DEFAULT_GAME_ARGS", enabled: true, value: "-pending", save: false)
        launcher.launch(model: model)
        launcher.launch(model: model)
        check(starts == 1 && exits == 1, "single handoff")
        let failing = LaunchController(spawn: { _, _ in throw LauncherError.message("spawn failed") }, terminate: { fatalError("must not quit") })
        failing.launch(model: model)
        check(failing.error == "spawn failed" && !failing.isLaunching, "recover spawn failure")
        try fm.removeItem(at: config)
        try fm.createDirectory(at: config, withIntermediateDirectories: false)
        let blocked = LaunchController(spawn: { _, _ in fatalError("must not spawn") }, terminate: { fatalError("must not quit") })
        blocked.launch(model: model)
        check(model.saveError != nil && blocked.error != nil, "save failure blocks launch")
        try fm.removeItem(at: config)
        model.selectTarget(exe)
        try fm.removeItem(at: exe)
        blocked.launch(model: model)
        check(blocked.error != nil, "missing target blocks launch")
        model.setVar("DEFAULT_GAME_ARGS", enabled: true, value: "bad\nline", save: false)
        check(!model.persist(), "reject multiline shell value")
        // The spawned helper must be independent of the native UI process.
        let witness = root.appendingPathComponent("child-survived")
        let child = root.appendingPathComponent("child-helper")
        try "#!/bin/sh\nsleep 0.2\nprintf survived > \(shellQuote(witness.path))\n".write(to: child, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: child.path)
        try LaunchController.startProcess(helper: child, log: root.appendingPathComponent("child.log"))
        let deadline = Date().addingTimeInterval(3)
        while !fm.fileExists(atPath: witness.path) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        check(fm.fileExists(atPath: witness.path), "child continues after handoff")
        print("Launcher model and handoff tests passed")
    }
}
