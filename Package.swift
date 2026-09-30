// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AnomalySetupTool",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "Anomaly Setup Tool", targets: ["AnomalySetupTool"]),
        .executable(name: "anomaly-setup-engine", targets: ["AnomalySetupEngine"]),
        .executable(name: "AnomalyLauncher", targets: ["AnomalyLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "AnomalyLauncher",
            path: "sources/AnomalyLauncher",
            exclude: ["Resources"]
        ),
        .target(
            name: "AnomalySetupCore",
            path: "sources/AnomalySetupCore"
        ),
        .executableTarget(
            name: "AnomalySetupTool",
            dependencies: ["AnomalySetupCore"],
            path: "sources/AnomalySetupTool",
            // wine-engine/ holds interactive_setup.py, which needs no
            // SwiftPM resource rule: WineEngineSetup.locateScript() finds it
            // by a literal filesystem path relative to the running executable
            // (Contents/Resources/wine-engine for the build.sh-built app,
            // sources/AnomalySetupTool/Resources/wine-engine for `swift run`),
            // never through Bundle.module — build.sh already copies the
            // whole directory into the built app independently of SwiftPM.
            // SetupTool.icon is compiled by build.sh with actool.
            exclude: ["Resources/wine-engine", "SetupTool.icon"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "AnomalySetupEngine",
            dependencies: ["AnomalySetupCore"],
            path: "sources/AnomalySetupEngine"
        )
    ]
)
