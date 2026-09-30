import Foundation

/// What the wrapper's bundled engine says about itself, read from the
/// `engine-manifest.json` the engine archive ships.
struct EngineInfo: Decodable, Equatable {
    struct Base: Decodable, Equatable {
        let wine: String?
    }

    struct DXMT: Decodable, Equatable {
        let tag: String?
        let commit: String?

        var shortCommit: String? { commit.map { String($0.prefix(7)) } }

        var releaseURL: URL? {
            tag.flatMap { URL(string: "https://github.com/elseform/dxmt/releases/tag/\($0)") }
        }
    }

    let engineId: String?
    let versionLabel: String?
    let buildNumber: Int?
    let base: Base?
    let dxmt: DXMT?

    /// The GitHub release the engine was published as: `engine-<engineId>-<build>`.
    var releaseURL: URL? {
        guard let engineId, let buildNumber else { return nil }
        return URL(string: "https://github.com/elseform/anomaly-wine-engine/releases/tag/engine-\(engineId)-\(buildNumber)")
    }

    static func load(install: InstallLayout) -> EngineInfo? {
        guard let url = install.engineManifestURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}
