import Foundation

struct PathsConfig: Decodable {
    let configFile: String
    let stateFile: String?
    let winePrefix: String?

    static func load(install: InstallLayout) -> PathsConfig? {
        guard let wrapper = install.wrapperURL,
              let data = try? Data(contentsOf: wrapper.appendingPathComponent("Contents/Resources/configurator-paths.json")) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}

struct InstallLayout {
    let wrapperURL: URL?

    static func current(bundleURL: URL = Bundle.main.bundleURL) -> InstallLayout {
        let helper = bundleURL.appendingPathComponent("Contents/MacOS/launcher")
        return InstallLayout(wrapperURL: FileManager.default.isExecutableFile(atPath: helper.path) ? bundleURL : nil)
    }

    var engineManifestURL: URL? {
        wrapperURL?.appendingPathComponent("Contents/Resources/engine/engine-manifest.json")
    }
}
