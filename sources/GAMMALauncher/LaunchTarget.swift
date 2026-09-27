import Foundation

struct LaunchTarget {
    let windowsPath: String
    let directory: URL

    static func isModOrganizer(_ path: String) -> Bool {
        path.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/").last?.lowercased() == "modorganizer.exe"
    }

    static func select(_ url: URL, prefix: URL) throws -> LaunchTarget {
        let file = url.standardizedFileURL.resolvingSymlinksInPath()
        try validate(file)
        for drive in ["g", "z"] {
            let mapping = prefix.appendingPathComponent("dosdevices/\(drive):").resolvingSymlinksInPath().standardizedFileURL
            let base = mapping.path == "/" ? "/" : mapping.path + "/"
            guard file.path.hasPrefix(base) else { continue }
            let relative = String(file.path.dropFirst(base.count)).replacingOccurrences(of: "/", with: "\\")
            return LaunchTarget(windowsPath: "\(drive.uppercased()):\\\(relative)", directory: file.deletingLastPathComponent())
        }
        throw LauncherError.message("The executable is outside this prefix’s G: and Z: drive mappings.")
    }

    static func resolve(_ path: String, prefix: URL) throws -> URL {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        guard normalized.count >= 3 else { throw LauncherError.message("Choose a Windows executable.") }
        let chars = Array(normalized)
        guard chars[1] == ":", chars[2] == "/", chars[0].isASCII, chars[0].isLetter else {
            throw LauncherError.message("The executable must use an absolute Wine drive path.")
        }
        let mapping = prefix.appendingPathComponent("dosdevices/\(String(chars[0]).lowercased()):")
        guard FileManager.default.fileExists(atPath: mapping.path) else {
            throw LauncherError.message("The executable’s Wine drive mapping is missing.")
        }
        let file = mapping.resolvingSymlinksInPath().appendingPathComponent(String(chars.dropFirst(3))).standardizedFileURL
        try validate(file)
        return file
    }

    private static func validate(_ file: URL) throws {
        guard file.pathExtension.lowercased() == "exe",
              (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
              FileManager.default.isReadableFile(atPath: file.path) else {
            throw LauncherError.message("Choose an existing, readable Windows .exe file.")
        }
    }
}
