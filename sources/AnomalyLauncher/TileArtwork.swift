import AppKit

/// Loads the tile icons the wrapper carries in Contents/Resources, once each.
@MainActor
enum TileArtwork {
    private static var cache: [String: NSImage?] = [:]

    static func image(named name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        let image = Bundle.main.url(forResource: name, withExtension: "icns").flatMap { NSImage(contentsOf: $0) }
        cache[name] = .some(image)
        return image
    }
}
