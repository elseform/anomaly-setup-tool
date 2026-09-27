// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GAMMASetupTool",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "GAMMA Setup Tool", targets: ["GAMMASetupTool"]),
        .executable(name: "gamma-setup-engine", targets: ["GAMMASetupEngine"]),
        .executable(name: "GAMMALauncher", targets: ["GAMMALauncher"])
    ],
    targets: [
        .executableTarget(
            name: "GAMMALauncher",
            path: "sources/GAMMALauncher",
            exclude: ["Resources"]
        ),
        .target(
            name: "GAMMASetupCore",
            path: "sources/GAMMASetupCore"
        ),
        .executableTarget(
            name: "GAMMASetupTool",
            dependencies: ["GAMMASetupCore"],
            path: "sources/GAMMASetupTool",
            // wine-engine/ holds interactive_setup.py, which needs no
            // SwiftPM resource rule: WineEngineSetup.locateScript() finds it
            // by a literal filesystem path relative to the running executable
            // (Contents/Resources/wine-engine for the build.sh-built app,
            // sources/GAMMASetupTool/Resources/wine-engine for `swift run`),
            // never through Bundle.module — build.sh already copies the
            // whole directory into the built app independently of SwiftPM.
            // SetupTool.icon is compiled by build.sh with actool.
            exclude: ["Resources/wine-engine", "SetupTool.icon"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "GAMMASetupEngine",
            dependencies: ["GAMMASetupCore"],
            path: "sources/GAMMASetupEngine"
        )
    ]
)
