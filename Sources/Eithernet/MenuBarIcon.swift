import AppKit
import SwiftUI

enum MenuBarIcon: String {
    case both = "menubar-both"
    case wired = "menubar-wired"
    case wireless = "menubar-wireless"
    case off = "menubar-off"

    /// Menu-bar status items optically sit around 18pt; we use 20pt so custom
    /// glyphs match neighboring SF Symbol weight/size.
    private static let pointSize = NSSize(width: 20, height: 20)

    var nsImage: NSImage {
        if let cached = NSImage(named: rawValue) {
            return prepared(cached)
        }

        let url =
            Bundle.module.url(forResource: "\(rawValue)@2x", withExtension: "png")
            ?? Bundle.module.url(forResource: rawValue, withExtension: "png")

        if let url, let image = NSImage(contentsOf: url) {
            return prepared(image)
        }

        let symbolName: String
        switch self {
        case .both: symbolName = "cable.connector"
        case .wired: symbolName = "cable.connector"
        case .wireless: symbolName = "wifi"
        case .off: symbolName = "wifi.slash"
        }
        let fallback = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Eithernet"
        ) ?? NSImage()
        return prepared(fallback)
    }

    private func prepared(_ image: NSImage) -> NSImage {
        // Copy so we never mutate a shared/cached instance into the wrong size.
        let copy = image.copy() as? NSImage ?? image
        copy.isTemplate = true
        copy.size = Self.pointSize
        copy.resizingMode = .stretch
        if copy.name() == nil {
            copy.setName(rawValue)
        }
        return copy
    }
}
