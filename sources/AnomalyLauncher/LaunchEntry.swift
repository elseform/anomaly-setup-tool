import Foundation

/// The two executables a wrapper can launch. Each has its own saved path.
enum LaunchSlot {
    case modOrganizer
    case custom

    var pathKey: String {
        switch self {
        case .modOrganizer: "ANOMALY_MO2_EXE_PATH"
        case .custom: "ANOMALY_CUSTOM_EXE_PATH"
        }
    }

    var runDirKey: String {
        switch self {
        case .modOrganizer: "ANOMALY_MO2_EXE_RUN_DIR"
        case .custom: "ANOMALY_CUSTOM_EXE_RUN_DIR"
        }
    }
}

/// One tile of the launch grid.
struct LaunchEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case modOrganizer
        case anomalyDX11
        case anomalyDX11AVX
        case custom
    }

    let kind: Kind
    let label: String
    let slot: LaunchSlot
    /// Passed to the launch helper. Empty lets the helper apply its own
    /// default arguments, which is what the custom executable wants.
    let arguments: [String]

    var id: Kind { kind }

    /// The Anomaly tiles are Mod Organizer executable shortcuts, not direct
    /// paths. The name after moshortcut:// is the executable's title in Mod
    /// Organizer's own list.
    private static func shortcut(_ title: String) -> [String] { ["moshortcut://\(title)"] }

    static let modOrganizer = LaunchEntry(kind: .modOrganizer, label: "ModOrganizer", slot: .modOrganizer, arguments: [])
    static let anomalyDX11 = LaunchEntry(kind: .anomalyDX11, label: "Anomaly - DX11", slot: .modOrganizer, arguments: shortcut("Anomaly (DX11)"))
    static let anomalyDX11AVX = LaunchEntry(kind: .anomalyDX11AVX, label: "Anomaly - DX11 (AVX)", slot: .modOrganizer, arguments: shortcut("Anomaly (DX11-AVX)"))

    static func custom(path: String) -> LaunchEntry {
        let name = path.replacingOccurrences(of: "\\", with: "/").split(separator: "/").last.map(String.init) ?? path
        return LaunchEntry(kind: .custom, label: (name as NSString).deletingPathExtension, slot: .custom, arguments: [])
    }
}
