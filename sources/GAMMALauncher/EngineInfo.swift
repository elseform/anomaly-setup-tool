import Foundation

/// What the wrapper's bundled engine says about itself, read from the
/// `engine-manifest.json` the engine archive ships.
struct EngineInfo: Decodable, Equatable {
    struct Base: Decodable, Equatable {
        let crossover: String?
        let wine: String?
    }

    struct DXMT: Decodable, Equatable {
        let tag: String?
        let commit: String?

        var shortCommit: String? { commit.map { String($0.prefix(7)) } }
    }

    let versionLabel: String?
    let buildNumber: Int?
    let base: Base?
    let dxmt: DXMT?

    static func load(install: InstallLayout) -> EngineInfo? {
        guard let url = install.engineManifestURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}
