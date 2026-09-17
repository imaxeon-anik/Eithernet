import AppKit
import SwiftUI

enum MenuBarIcon: String {
    case both
    case wired
    case wireless
    case off

    /// Menu-bar status items optically sit around 18pt; we use 20pt to match SF Symbol weight.
    private static let pointSize: CGFloat = 20
    private static let squareSize = NSSize(width: pointSize, height: pointSize)
    /// Side-by-side composite needs extra width so cable + Wi‑Fi don’t overlap in the tray.
    private static let bothSize = NSSize(width: 30, height: pointSize)

    /// Space reserved in the menu bar (must match rendered image aspect ratio).
    var traySize: NSSize {
        switch self {
        case .both: return Self.bothSize
        default: return Self.squareSize
        }
    }

    var nsImage: NSImage {
        prepared(render())
    }

    private var symbolName: String? {
        switch self {
        case .wired: return "cable.connector"
        case .wireless: return "dot.radiowaves.left.and.right"
        case .off: return "network.slash"
        case .both: return nil
        }
    }

    private func render() -> NSImage {
        if self == .both {
            return Self.compositeBothImage()
        }
        guard let symbolName,
              let image = Self.symbolImage(named: symbolName, pointSize: Self.pointSize)
        else {
            return NSImage(size: Self.squareSize)
        }
        return image
    }

    private static func symbolImage(named name: String, pointSize: CGFloat) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: "Eithernet") else {
            return nil
        }
        return base.withSymbolConfiguration(config)
    }

    /// Cable left, radiowaves right — wide canvas, no overlap.
    private static func compositeBothImage() -> NSImage {
        let canvas = bothSize
        let symbolHeight = pointSize * 0.82
        let left = symbolImage(named: "cable.connector", pointSize: symbolHeight * 0.95)
        let right = symbolImage(named: "dot.radiowaves.left.and.right", pointSize: symbolHeight * 0.88)

        let image = NSImage(size: canvas)
        image.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: canvas).fill()

        let verticalInset = (canvas.height - symbolHeight) / 2
        let leftWidth = canvas.width * 0.38
        let rightWidth = canvas.width * 0.58
        let gap = canvas.width - leftWidth - rightWidth

        left?.draw(
            in: NSRect(x: 0, y: verticalInset, width: leftWidth, height: symbolHeight),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        right?.draw(
            in: NSRect(
                x: leftWidth + gap,
                y: verticalInset,
                width: rightWidth,
                height: symbolHeight
            ),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        return image
    }

    private func prepared(_ image: NSImage) -> NSImage {
        let size = traySize
        let copy = image.copy() as? NSImage ?? image
        copy.isTemplate = true
        copy.size = size
        copy.resizingMode = .stretch
        if copy.name() == nil {
            copy.setName(rawValue)
        }
        return copy
    }
}
