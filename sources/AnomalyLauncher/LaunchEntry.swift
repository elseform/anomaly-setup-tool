import Foundation

/// Which saved executable a tile starts.
enum LaunchSource: Equatable {
    case modOrganizer
    case custom(UUID)
}

/// One tile of the launch grid.
struct LaunchEntry: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case modOrganizer
        case anomalyDX11
        case anomalyDX11AVX
        case custom
    }

    let kind: Kind
    let source: LaunchSource
    let label: String
    /// Passed to the launch helper. Empty lets the helper apply its own
    /// default arguments, which is what custom executables want.
    let arguments: [String]

    var id: String {
        if case .custom(let uuid) = source { return uuid.uuidString }
        return kind.rawValue
    }

    /// The Anomaly tiles are Mod Organizer executable shortcuts, not direct
    /// paths. The name after moshortcut:// is the executable's title in Mod
    /// Organizer's own list.
    private static func shortcut(_ title: String) -> [String] { ["moshortcut://\(title)"] }

    static let modOrganizer = LaunchEntry(kind: .modOrganizer, source: .modOrganizer, label: "ModOrganizer", arguments: [])
    static let anomalyDX11 = LaunchEntry(kind: .anomalyDX11, source: .modOrganizer, label: "Anomaly - DX11", arguments: shortcut("Anomaly (DX11)"))
    static let anomalyDX11AVX = LaunchEntry(kind: .anomalyDX11AVX, source: .modOrganizer, label: "Anomaly - DX11 (AVX)", arguments: shortcut("Anomaly (DX11-AVX)"))

    static func custom(_ executable: CustomExecutable) -> LaunchEntry {
        LaunchEntry(kind: .custom, source: .custom(executable.id), label: executable.label, arguments: [])
    }
}
