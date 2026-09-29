import Foundation

// Started as a port of the former runtime/configurator/configurator.py's
// SCHEMA; this is the only copy now. It defines what app.env lines get
// written, so keys, kinds and always_on/quoted flags must stay compatible with
// existing installs' app.env files. Where each setting appears in the window
// is decided separately, by SettingCategory below.
// Defaults must match the app.env seed in gamma-setup-tool's
// interactive_setup.py, which is what a new wrapper actually starts from.
enum SchemaKind {
    case bool
    case text
    case retina
}

struct SchemaEntry {
    let key: String
    let kind: SchemaKind
    let alwaysOn: Bool
    let quoted: Bool
    let defaultValue: String
    /// Whether a brand-new state writes this optional key. An existing
    /// app.env without the line keeps it off.
    var enabledByDefault = false

    /// Whether a new install has the line.
    var enabledInNewInstall: Bool { alwaysOn || enabledByDefault }
}

let schema: [SchemaEntry] = [
    // Not shown: D3DMetal is no longer offered, so this is always dxmt. Still
    // written because the launcher and cxcompatdb read it.
    SchemaEntry(key: "GAMMA_GRAPHICS_BACKEND", kind: .text, alwaysOn: true, quoted: false, defaultValue: "dxmt"),

    SchemaEntry(key: "WINEMSYNC", kind: .bool, alwaysOn: true, quoted: false, defaultValue: "1"),
    SchemaEntry(key: "WINEESYNC", kind: .bool, alwaysOn: true, quoted: false, defaultValue: "1"),
    SchemaEntry(key: "ROSETTA_ADVERTISE_AVX", kind: .bool, alwaysOn: true, quoted: false, defaultValue: "0"),
    SchemaEntry(key: "GAMMA_RETINA_MODE", kind: .retina, alwaysOn: true, quoted: false, defaultValue: "N"),
    SchemaEntry(key: "GAMMA_RETINA_LOGPIXELS", kind: .text, alwaysOn: false, quoted: false, defaultValue: ""),
    SchemaEntry(key: "MTL_HUD_ENABLED", kind: .bool, alwaysOn: true, quoted: false, defaultValue: "0"),
    SchemaEntry(key: "WINEDEBUG", kind: .text, alwaysOn: true, quoted: true, defaultValue: "-all"),

    SchemaEntry(key: "DEFAULT_GAME_ARGS", kind: .text, alwaysOn: true, quoted: true, defaultValue: ""),

    SchemaEntry(key: "DXMT_METALFX_SPATIAL_SWAPCHAIN", kind: .bool, alwaysOn: true, quoted: false, defaultValue: "0"),
    SchemaEntry(key: "DXMT_ENABLE_NVEXT", kind: .bool, alwaysOn: true, quoted: false, defaultValue: "1"),
    SchemaEntry(key: "DXMT_REORDER_BLITS", kind: .bool, alwaysOn: false, quoted: false, defaultValue: "1", enabledByDefault: true),
    SchemaEntry(key: "DXMT_FRAME_LIMITER", kind: .bool, alwaysOn: false, quoted: false, defaultValue: "0"),

    SchemaEntry(key: "DXMT_SHADER_CACHE", kind: .text, alwaysOn: false, quoted: false, defaultValue: "1"),
    SchemaEntry(key: "DXMT_SHADER_CACHE_PATH", kind: .text, alwaysOn: false, quoted: false, defaultValue: ""),

    SchemaEntry(key: "DXMT_LOG_LEVEL", kind: .text, alwaysOn: false, quoted: false, defaultValue: "none"),
    SchemaEntry(key: "DXMT_LOG_PATH", kind: .text, alwaysOn: false, quoted: false, defaultValue: ""),
    SchemaEntry(key: "DXMT_CAPTURE_FRAME", kind: .text, alwaysOn: false, quoted: false, defaultValue: ""),
    SchemaEntry(key: "DXMT_CAPTURE_EXECUTABLE", kind: .text, alwaysOn: false, quoted: false, defaultValue: ""),
    SchemaEntry(key: "DXMT_CONFIG_FILE", kind: .text, alwaysOn: false, quoted: false, defaultValue: ""),

    // Apple's Metal debugging switches, read when the Metal device is created.
    // MTL_CAPTURE_ENABLED is what lets DXMT_CAPTURE_* take a GPU trace at all.
    SchemaEntry(key: "MTL_CAPTURE_ENABLED", kind: .bool, alwaysOn: false, quoted: false, defaultValue: "0"),
    SchemaEntry(key: "MTL_DEBUG_LAYER", kind: .bool, alwaysOn: false, quoted: false, defaultValue: "0"),
    SchemaEntry(key: "MTL_SHADER_VALIDATION", kind: .bool, alwaysOn: false, quoted: false, defaultValue: "0"),

    // DXMT_CONFIG itself is handled separately (dxmtConfig / dxmtConfigKeys below).
]

let schemaByKey: [String: SchemaEntry] = Dictionary(uniqueKeysWithValues: schema.map { ($0.key, $0) })

/// Env keys of D3DMetal's settings, which the Configurator no longer offers.
/// Lines for them are dropped from app.env instead of kept as unrecognised.
let retiredKeyPrefixes = ["D3DM_"]

enum DXMTConfigKind {
    case bool
    case int
    case float
    case text
    case enumChoice
}

struct DXMTConfigEntry {
    let key: String
    let kind: DXMTConfigKind
    let choices: [String]?
    let defaultValue: String
    /// Whether a brand-new state (no app.env to seed from) packs this key
    /// into DXMT_CONFIG. Everything else stays off until someone enables it.
    var enabledByDefault = false
}

// Direct port of DXMT_CONFIG_KEYS.
let dxmtConfigKeys: [DXMTConfigEntry] = [
    DXMTConfigEntry(key: "d3d11.maxFeatureLevel", kind: .enumChoice, choices: ["9_1", "9_2", "9_3", "10_0", "10_1", "11_0", "11_1", "12_0", "12_1"], defaultValue: "11_1"),
    DXMTConfigEntry(key: "d3d11.preferredMaxFrameRate", kind: .int, choices: nil, defaultValue: "60"),
    // DXMT Tristate: auto follows the game's Present sync interval (vsync-updates builds only).
    DXMTConfigEntry(key: "d3d11.displaySync", kind: .enumChoice, choices: ["auto", "true", "false"], defaultValue: "auto", enabledByDefault: true),
    DXMTConfigEntry(key: "d3d11.metalSpatialUpscaleFactor", kind: .float, choices: nil, defaultValue: "1.0"),
    DXMTConfigEntry(key: "d3d11.ignoreMapFlagNoWait", kind: .bool, choices: nil, defaultValue: "false"),
    DXMTConfigEntry(key: "d3d11.sampleNaNToZero", kind: .bool, choices: nil, defaultValue: "true", enabledByDefault: true),
    DXMTConfigEntry(key: "d3d11.defuseFma", kind: .bool, choices: nil, defaultValue: "false"),
    DXMTConfigEntry(key: "d3d11.releaseShaderIR", kind: .bool, choices: nil, defaultValue: "true", enabledByDefault: true),
    DXMTConfigEntry(key: "dxmt.shaderMetalVersion", kind: .enumChoice, choices: ["310", "320"], defaultValue: "310"),
    DXMTConfigEntry(key: "dxgi.customVendorId", kind: .text, choices: nil, defaultValue: ""),
    DXMTConfigEntry(key: "dxgi.customDeviceId", kind: .text, choices: nil, defaultValue: ""),
    DXMTConfigEntry(key: "dxgi.customDeviceDesc", kind: .text, choices: nil, defaultValue: ""),
    DXMTConfigEntry(key: "dxgi.forceSDR", kind: .bool, choices: nil, defaultValue: "true", enabledByDefault: true),
    DXMTConfigEntry(key: "dxgi.handleAltTab", kind: .bool, choices: nil, defaultValue: "false"),
]

// EXE_PATH/EXE_RUN_DIR are edited together by the target picker, not rendered as
// GUI fields; carried through every regeneration as opaque strings.
let passthroughKeys = ["EXE_PATH", "EXE_RUN_DIR"]

let pointerComment = "# Edit via the wrapper app — see it for descriptions and valid ranges."

// User-facing labels and one-line descriptions shown by default; the raw
// env-var/DXMT_CONFIG key is shown on hover (.help) instead, so this file
// stays the single place that needs updating when a key's wording changes.
let friendlyLabels: [String: String] = [
    "MTL_HUD_ENABLED": "Metal HUD Overlay",
    "MTL_CAPTURE_ENABLED": "GPU Frame Capture",
    "MTL_DEBUG_LAYER": "Metal API Validation",
    "MTL_SHADER_VALIDATION": "Metal Shader Validation",
    "WINEMSYNC": "Msync",
    "WINEESYNC": "Esync",
    "ROSETTA_ADVERTISE_AVX": "Advertise AVX Under Rosetta",
    "WINEDEBUG": "Wine Debug Channels",
    "DEFAULT_GAME_ARGS": "Launch Arguments",
    "GAMMA_RETINA_MODE": "Retina Resolution",
    "GAMMA_RETINA_LOGPIXELS": "Retina DPI Override",

    "DXMT_METALFX_SPATIAL_SWAPCHAIN": "MetalFX Upscaling",
    "DXMT_ENABLE_NVEXT": "DLSS Support",
    "DXMT_REORDER_BLITS": "Blit Encoder Merging",
    "DXMT_FRAME_LIMITER": "Frame Limiter",
    "DXMT_LOG_LEVEL": "Log Level",
    "DXMT_LOG_PATH": "Log File Path",
    "DXMT_SHADER_CACHE": "Shader Cache",
    "DXMT_SHADER_CACHE_PATH": "Shader Cache Path",
    "DXMT_CAPTURE_FRAME": "Frame Capture Trigger",
    "DXMT_CAPTURE_EXECUTABLE": "Capture Target",
    "DXMT_CONFIG_FILE": "DXMT Config File Override",

    "d3d11.maxFeatureLevel": "Max DirectX Feature Level",
    "d3d11.preferredMaxFrameRate": "Preferred Max Frame Rate",
    "d3d11.displaySync": "V-Sync",
    "d3d11.metalSpatialUpscaleFactor": "Upscale Factor",
    "d3d11.ignoreMapFlagNoWait": "Ignore Map No-Wait Flag",
    "d3d11.sampleNaNToZero": "Clamp NaN Samples To Zero",
    "d3d11.defuseFma": "Disable Fused Multiply-Add",
    "d3d11.releaseShaderIR": "Release Shader IR",
    "dxmt.shaderMetalVersion": "Metal Shading Language Version",
    "dxgi.customVendorId": "Custom Vendor ID",
    "dxgi.customDeviceId": "Custom Device ID",
    "dxgi.customDeviceDesc": "Custom Device Description",
    "dxgi.forceSDR": "Force SDR Output",
    "dxgi.handleAltTab": "Handle Alt+Tab",
]

let friendlyDescriptions: [String: String] = [
    "MTL_HUD_ENABLED": "Shows Apple's Metal HUD with frame rate and GPU stats.",
    "MTL_CAPTURE_ENABLED": "Allows Metal GPU trace capture. Also needs the Metal Frame Capture Tool; F10 then captures a frame. Traces are large, around 15 GB.",
    "MTL_DEBUG_LAYER": "Checks Metal API calls for misuse. Cheap, but not free; leave off for normal play.",
    "MTL_SHADER_VALIDATION": "Checks shader memory access on the GPU. Slow; errors go to the system log (Console). Leave off for normal play.",
    "WINEMSYNC": "Faster thread synchronization in Wine. Turn off only to troubleshoot.",
    "WINEESYNC": "Fallback thread synchronization in Wine. Turn off only to troubleshoot.",
    "ROSETTA_ADVERTISE_AVX": "Tells the game the CPU supports AVX under Rosetta.",
    "WINEDEBUG": "Which Wine debug messages are logged. \"-all\" logs none.",
    "DEFAULT_GAME_ARGS": "Extra arguments passed to the program the wrapper launches.",
    "GAMMA_RETINA_MODE": "Lets the game use your display's full Retina resolution.",
    "GAMMA_RETINA_LOGPIXELS": "Windows DPI to use in Retina mode.",

    "DXMT_METALFX_SPATIAL_SWAPCHAIN": "Upscales the final image with Apple MetalFX.",
    "DXMT_ENABLE_NVEXT": "Needed for the game's DLSS options.",
    "DXMT_REORDER_BLITS": "Groups independent copy and upload work to reduce encoder and render-pass splits.",
    "DXMT_FRAME_LIMITER": "Paces the game itself, not only the display, to Preferred Max Frame Rate, or to half the display's refresh rate when that is off. Game timing and input then follow the same steady rhythm as the screen.",
    "DXMT_LOG_LEVEL": "How much DXMT writes to its log.",
    "DXMT_LOG_PATH": "Folder for DXMT log files. \"none\" writes no log files.",
    "DXMT_SHADER_CACHE": "Set to 0 to turn off DXMT's shader cache.",
    "DXMT_SHADER_CACHE_PATH": "Absolute path of the folder for the shader cache.",
    "DXMT_CAPTURE_FRAME": "Captures this frame number automatically, without pressing F10.",
    "DXMT_CAPTURE_EXECUTABLE": "Executable name, without extension, to allow Metal frame capture for, for example AnomalyDX11.",
    "DXMT_CONFIG_FILE": "Path of a dxmt.conf file to read DXMT options from.",

    "d3d11.maxFeatureLevel": "Highest DirectX 11 feature level reported to the game.",
    "d3d11.preferredMaxFrameRate": "Frame rate cap paced by Metal. Use a factor of your display's refresh rate, like 30, 60 or 120. Also the Frame Limiter's target.",
    "d3d11.displaySync": "Syncs frames to the display. Auto follows the game's own V-Sync setting.",
    "d3d11.metalSpatialUpscaleFactor": "Output size multiplier, above 1.0. For example, 1.33 turns 1080p into 1440p.",
    "d3d11.ignoreMapFlagNoWait": "Workaround for games that mishandle a D3D11 no-wait map flag.",
    "d3d11.sampleNaNToZero": "Reads invalid (NaN) texture samples as zero.",
    "d3d11.defuseFma": "Compiles shaders without fused multiply-add.",
    "d3d11.releaseShaderIR": "Frees parsed shader data after compilation to reduce memory use.",
    "dxmt.shaderMetalVersion": "310 is Metal 3.1 (macOS 14+), 320 is Metal 3.2 (macOS 15+). Default uses the newest supported.",
    "dxgi.customVendorId": "GPU vendor ID reported to the game.",
    "dxgi.customDeviceId": "GPU device ID reported to the game.",
    "dxgi.customDeviceDesc": "GPU name reported to the game.",
    "dxgi.forceSDR": "Never uses HDR output.",
    "dxgi.handleAltTab": "Lets DXMT handle Cmd+Tab in exclusive fullscreen.",
]

/// A row in the window: an app.env key or a DXMT_CONFIG sub-key.
enum SettingRef: Hashable {
    case env(String)
    case dxmt(String)

    var key: String {
        switch self {
        case .env(let key), .dxmt(let key): key
        }
    }
}

struct SettingGroup {
    let title: String
    let settings: [SettingRef]
    var help: String? = nil
}

/// A sidebar entry in the window. Every setting except GAMMA_GRAPHICS_BACKEND
/// appears in exactly one category.
enum SidebarSection {
    case game, advanced, info
}

enum SettingCategory: String, CaseIterable, Identifiable {
    case launch
    case frameRate
    case display
    case upscaling
    case performance
    case renderingFixes
    case compatibility
    case wine
    case debugging
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .launch: "Launch"
        case .frameRate: "Frame Rate & Sync"
        case .display: "Display"
        case .upscaling: "Upscaling"
        case .performance: "Performance"
        case .renderingFixes: "Rendering Fixes"
        case .compatibility: "Compatibility"
        case .wine: "Wine"
        case .debugging: "Debugging"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .launch: "play.circle"
        case .frameRate: "speedometer"
        case .display: "display"
        case .upscaling: "arrow.up.left.and.arrow.down.right"
        case .performance: "gauge.with.dots.needle.67percent"
        case .renderingFixes: "wrench.and.screwdriver"
        case .compatibility: "puzzlepiece.extension"
        case .wine: "wineglass"
        case .debugging: "ladybug"
        case .about: "info.circle"
        }
    }

    /// The sidebar heading the category is listed under.
    var sidebarSection: SidebarSection {
        switch self {
        case .launch, .frameRate, .display, .upscaling: .game
        case .about: .info
        default: .advanced
        }
    }

    /// Sections of the category's page, in window order.
    var groups: [SettingGroup] {
        switch self {
        case .launch:
            [SettingGroup(title: "Launch", settings: [
                .env("DEFAULT_GAME_ARGS"),
            ])]
        case .frameRate:
            [SettingGroup(title: "Frame Rate & Sync", settings: [
                .dxmt("d3d11.displaySync"),
                .dxmt("d3d11.preferredMaxFrameRate"),
                .env("DXMT_FRAME_LIMITER"),
            ])]
        case .display:
            [SettingGroup(title: "Display", settings: [
                .env("GAMMA_RETINA_MODE"),
                .env("GAMMA_RETINA_LOGPIXELS"),
                .dxmt("dxgi.forceSDR"),
                .dxmt("dxgi.handleAltTab"),
            ])]
        case .upscaling:
            [SettingGroup(title: "Upscaling", settings: [
                .env("DXMT_ENABLE_NVEXT"),
                .env("DXMT_METALFX_SPATIAL_SWAPCHAIN"),
                .dxmt("d3d11.metalSpatialUpscaleFactor"),
            ])]
        case .performance:
            [
                SettingGroup(title: "Shaders & Encoding", settings: [
                    .dxmt("d3d11.releaseShaderIR"),
                    .env("DXMT_REORDER_BLITS"),
                ]),
                SettingGroup(title: "Shader Cache", settings: [
                    .env("DXMT_SHADER_CACHE"),
                    .env("DXMT_SHADER_CACHE_PATH"),
                ]),
            ]
        case .renderingFixes:
            [SettingGroup(title: "Rendering Fixes", settings: [
                .dxmt("d3d11.sampleNaNToZero"),
                .dxmt("d3d11.defuseFma"),
                .dxmt("d3d11.ignoreMapFlagNoWait"),
            ], help: "Default leaves the option to DXMT's own built-in default.")]
        case .compatibility:
            [
                SettingGroup(title: "Graphics", settings: [
                    .dxmt("d3d11.maxFeatureLevel"),
                    .dxmt("dxmt.shaderMetalVersion"),
                ]),
                SettingGroup(title: "GPU Identity", settings: [
                    .dxmt("dxgi.customVendorId"),
                    .dxmt("dxgi.customDeviceId"),
                    .dxmt("dxgi.customDeviceDesc"),
                ]),
            ]
        case .wine:
            [SettingGroup(title: "Wine", settings: [
                .env("WINEMSYNC"),
                .env("WINEESYNC"),
                .env("ROSETTA_ADVERTISE_AVX"),
            ])]
        case .about:
            []
        case .debugging:
            [
                SettingGroup(title: "Logging", settings: [
                    .env("WINEDEBUG"),
                    .env("DXMT_LOG_LEVEL"),
                    .env("DXMT_LOG_PATH"),
                ]),
                SettingGroup(title: "Metal: Debug", settings: [
                    .env("MTL_HUD_ENABLED"),
                    .env("MTL_CAPTURE_ENABLED"),
                    .env("DXMT_CAPTURE_EXECUTABLE"),
                    .env("DXMT_CAPTURE_FRAME"),
                    .env("MTL_DEBUG_LAYER"),
                    .env("MTL_SHADER_VALIDATION"),
                ], help: "Capture, API validation and shader validation are read when the game starts. Validation slows the game down."),
                SettingGroup(title: "Overrides", settings: [
                    .env("DXMT_CONFIG_FILE"),
                ]),
            ]
        }
    }
}

/// Rows shown only while the named app.env switch is on.
let shownOnlyWhenOn: [String: String] = [
    "DXMT_CAPTURE_EXECUTABLE": "MTL_CAPTURE_ENABLED",
    "DXMT_CAPTURE_FRAME": "MTL_CAPTURE_ENABLED",
    "GAMMA_RETINA_LOGPIXELS": "GAMMA_RETINA_MODE",
    "d3d11.metalSpatialUpscaleFactor": "DXMT_METALFX_SPATIAL_SWAPCHAIN",
]

let dxmtConfigByKey: [String: DXMTConfigEntry] = Dictionary(uniqueKeysWithValues: dxmtConfigKeys.map { ($0.key, $0) })

func friendlyLabel(for key: String) -> String {
    friendlyLabels[key] ?? key
}

func friendlyDescription(for key: String) -> String? {
    friendlyDescriptions[key]
}
