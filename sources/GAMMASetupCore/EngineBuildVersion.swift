import Foundation

/// A published engine build, ordered so "which release is newest?" has one
/// answer: CrossOver major, then Wine major, then the build counter.
///
/// Only the majors take part. Tags up to build 17 carried the full CrossOver
/// version and a hand-bumped GAMMA counter (`engine-cx26.3-w11-gamma087-15`);
/// later ones carry just the majors (`engine-cx26-w11-gamma-19`). The build
/// counter is monotonic across that change, so ordering by it keeps the newer
/// tag form on top.
public struct EngineBuildVersion: Comparable, CustomStringConvertible {
    public let crossoverMajor: Int
    public let wineMajor: Int
    public let build: Int

    public init(crossoverMajor: Int, wineMajor: Int, build: Int) {
        self.crossoverMajor = crossoverMajor
        self.wineMajor = wineMajor
        self.build = build
    }

    public var description: String {
        "CX\(crossoverMajor)-W\(wineMajor)-GAMMA build \(build)"
    }

    public static func < (lhs: EngineBuildVersion, rhs: EngineBuildVersion) -> Bool {
        (lhs.crossoverMajor, lhs.wineMajor, lhs.build) < (rhs.crossoverMajor, rhs.wineMajor, rhs.build)
    }
}

public enum EngineVersionParser {
    /// `CX26-W11-GAMMA`, the `cx26-w11-gamma` slug, or the legacy
    /// `CX26.3.0-W11-Gamma087` / `cx26.3-w11-gamma087` forms. Anything after
    /// the CrossOver major is ignored.
    public static func parseLabel(_ raw: String) -> (crossoverMajor: Int, wineMajor: Int)? {
        let parts = raw.lowercased().split(separator: "-")
        guard parts.count >= 3 else { return nil }
        guard parts[0].hasPrefix("cx"), parts[1].hasPrefix("w"), parts[2].hasPrefix("gamma") else { return nil }
        guard let crossoverMajor = parts[0].dropFirst(2).split(separator: ".").first.flatMap({ Int($0) }),
              let wineMajor = Int(parts[1].dropFirst(1)) else { return nil }
        return (crossoverMajor, wineMajor)
    }

    /// The trailing `-<N>` of an archive name or release tag, with or without
    /// a compression suffix: `CX26W11-GAMMA-DXMT-14.tar.zst`,
    /// `CX26W11Gamma086-4.tar.xz`, `engine-cx26-w11-gamma-19`.
    public static func parseBuildCounter(fromName name: String) -> Int? {
        var stem = name
        for suffix in [".tar.zst", ".tar.xz"] where stem.hasSuffix(suffix) {
            stem = String(stem.dropLast(suffix.count))
        }
        guard let dash = stem.lastIndex(of: "-") else { return nil }
        return Int(stem[stem.index(after: dash)...])
    }
}
