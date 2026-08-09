#!/usr/bin/env swift
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Clean SF Symbols-like template menu-bar icons + macOS app icon.
/// Drawn at optical size with rounded strokes (not downscaled illustrations).

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let menuBarDir = root.appendingPathComponent("Sources/Eithernet/Resources")
let appIconDir = root.appendingPathComponent("Resources")
try FileManager.default.createDirectory(at: menuBarDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: appIconDir, withIntermediateDirectories: true)

enum Glyph { case both, wired, wireless, off }

func drawGlyph(_ glyph: Glyph, in rect: CGRect, ctx: CGContext, color: CGColor) {
    ctx.saveGState()
    defer { ctx.restoreGState() }

    ctx.setStrokeColor(color)
    ctx.setFillColor(color)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Match system menu-bar optical weight/size (fill most of the 18pt cell).
    let line = max(1.35, min(2.1, rect.width * 0.12))
    ctx.setLineWidth(line)

    // Tiny margin only — previous insets made the tray glyph look half-size.
    let inset = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.05)
    let midX = inset.midX

    func strokeRoundedRect(_ r: CGRect, corner: CGFloat) {
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: corner, cornerHeight: corner, transform: nil))
        ctx.strokePath()
    }

    func fillRoundedRect(_ r: CGRect, corner: CGFloat) {
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: corner, cornerHeight: corner, transform: nil))
        ctx.fillPath()
    }

    /// Ethernet plug sitting in the lower portion of `area`.
    func drawPlug(in area: CGRect, detailed: Bool) {
        let bodyW = area.width * 0.72
        let bodyH = area.height * (detailed ? 0.70 : 0.78)
        let body = CGRect(
            x: area.midX - bodyW / 2,
            y: area.minY + area.height * 0.10,
            width: bodyW,
            height: bodyH
        )
        strokeRoundedRect(body, corner: bodyW * 0.18)

        // Latch
        let tabW = bodyW * 0.40
        let tabH = max(line, bodyH * 0.16)
        let tab = CGRect(x: area.midX - tabW / 2, y: body.maxY - tabH * 0.25, width: tabW, height: tabH)
        strokeRoundedRect(tab, corner: tabH * 0.35)

        if detailed {
            let pinCount = 4
            let span = bodyW * 0.58
            let startX = area.midX - span / 2
            let y0 = body.maxY - bodyH * 0.30
            let y1 = body.midY + bodyH * 0.02
            ctx.setLineWidth(line * 0.85)
            for i in 0..<pinCount {
                let t = CGFloat(i) / CGFloat(pinCount - 1)
                let x = startX + span * t
                ctx.move(to: CGPoint(x: x, y: y0))
                ctx.addLine(to: CGPoint(x: x, y: y1))
            }
            ctx.strokePath()
            ctx.setLineWidth(line)
        }

        // Cable stub
        let stub = max(line * 1.2, area.height * 0.10)
        ctx.setLineWidth(line * 1.1)
        ctx.move(to: CGPoint(x: area.midX, y: body.minY))
        ctx.addLine(to: CGPoint(x: area.midX, y: max(area.minY, body.minY - stub)))
        ctx.strokePath()
        ctx.setLineWidth(line)
    }

    /// Wi‑Fi-style arcs opening upward from `origin`.
    func drawArcs(origin: CGPoint, maxRadius: CGFloat, count: Int) {
        for i in 1...count {
            let r = maxRadius * CGFloat(i) / CGFloat(count)
            ctx.addArc(
                center: origin,
                radius: r,
                startAngle: .pi * 0.18,
                endAngle: .pi * 0.82,
                clockwise: false
            )
            ctx.strokePath()
        }
        let dot = max(1.2, line * 0.62)
        ctx.fillEllipse(in: CGRect(x: origin.x - dot, y: origin.y - dot, width: dot * 2, height: dot * 2))
    }

    switch glyph {
    case .wired:
        drawPlug(in: inset, detailed: true)

    case .wireless:
        // Distinct from system Wi‑Fi: large arcs over a port capsule (fills the cell).
        let origin = CGPoint(x: midX, y: inset.minY + inset.height * 0.26)
        drawArcs(origin: origin, maxRadius: inset.width * 0.48, count: 3)
        let barW = inset.width * 0.46
        let barH = line * 1.25
        let bar = CGRect(
            x: midX - barW / 2,
            y: inset.minY + inset.height * 0.02,
            width: barW,
            height: barH
        )
        fillRoundedRect(bar, corner: barH / 2)

    case .both:
        let plugArea = CGRect(
            x: inset.minX + inset.width * 0.12,
            y: inset.minY,
            width: inset.width * 0.76,
            height: inset.height * 0.48
        )
        drawPlug(in: plugArea, detailed: false)
        let origin = CGPoint(x: midX, y: inset.minY + inset.height * 0.46)
        drawArcs(origin: origin, maxRadius: inset.width * 0.46, count: 2)

    case .off:
        let plugArea = CGRect(
            x: inset.minX + inset.width * 0.12,
            y: inset.minY,
            width: inset.width * 0.76,
            height: inset.height * 0.46
        )
        drawPlug(in: plugArea, detailed: false)
        let origin = CGPoint(x: midX, y: inset.minY + inset.height * 0.44)
        drawArcs(origin: origin, maxRadius: inset.width * 0.44, count: 2)
        ctx.setLineWidth(line * 1.25)
        ctx.move(to: CGPoint(x: inset.minX + inset.width * 0.06, y: inset.minY + inset.height * 0.08))
        ctx.addLine(to: CGPoint(x: inset.maxX - inset.width * 0.06, y: inset.maxY - inset.height * 0.06))
        ctx.strokePath()
    }
}

func makeContext(size: Int) -> (CGContext, UnsafeMutablePointer<UInt8>) {
    let bytesPerRow = size * 4
    let data = UnsafeMutablePointer<UInt8>.allocate(capacity: size * bytesPerRow)
    data.initialize(repeating: 0, count: size * bytesPerRow)
    let ctx = CGContext(
        data: data,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // CGBitmapContext is already y-up.
    return (ctx, data)
}

func pngData(from ctx: CGContext) -> Data {
    let image = ctx.makeImage()!
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    return try! Data(contentsOf: url)
}

func makeTemplatePNG(glyph: Glyph, pointSize: CGFloat, scale: CGFloat) -> Data {
    let px = Int((pointSize * scale).rounded())
    let (ctx, data) = makeContext(size: px)
    defer { data.deallocate() }
    ctx.saveGState()
    ctx.scaleBy(x: scale, y: scale)
    drawGlyph(
        glyph,
        in: CGRect(x: 0, y: 0, width: pointSize, height: pointSize),
        ctx: ctx,
        color: NSColor.black.cgColor
    )
    ctx.restoreGState()
    return pngData(from: ctx)
}

func makeAppIconPNG(pixelSize: Int) -> Data {
    let (ctx, data) = makeContext(size: pixelSize)
    defer { data.deallocate() }

    let margin = CGFloat(pixelSize) * 0.02
    let rect = CGRect(x: margin, y: margin, width: CGFloat(pixelSize) - margin * 2, height: CGFloat(pixelSize) - margin * 2)
    let radius = CGFloat(pixelSize) * 0.2237
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    let colors = [
        NSColor(calibratedRed: 0.11, green: 0.20, blue: 0.26, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.09, green: 0.40, blue: 0.44, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.14, green: 0.56, blue: 0.50, alpha: 1).cgColor,
    ] as CFArray
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 0.55, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: CGFloat(pixelSize), y: CGFloat(pixelSize)),
        options: []
    )

    // Soft specular (top)
    let highlight = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor.white.withAlphaComponent(0.22).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        highlight,
        start: CGPoint(x: CGFloat(pixelSize) * 0.5, y: CGFloat(pixelSize)),
        end: CGPoint(x: CGFloat(pixelSize) * 0.5, y: CGFloat(pixelSize) * 0.45),
        options: []
    )
    ctx.restoreGState()

    let glyphInset = CGFloat(pixelSize) * 0.20
    drawGlyph(
        .both,
        in: CGRect(
            x: glyphInset,
            y: glyphInset,
            width: CGFloat(pixelSize) - glyphInset * 2,
            height: CGFloat(pixelSize) - glyphInset * 2
        ),
        ctx: ctx,
        color: NSColor.white.cgColor
    )

    return pngData(from: ctx)
}

func writeMenuBarIcons() throws {
    let mapping: [(Glyph, String)] = [
        (.both, "menubar-both"),
        (.wired, "menubar-wired"),
        (.wireless, "menubar-wireless"),
        (.off, "menubar-off"),
    ]
    // 20pt cell matches neighboring menu-bar icons better than a padded 18pt glyph.
    let pointSize: CGFloat = 20
    for (glyph, name) in mapping {
        try makeTemplatePNG(glyph: glyph, pointSize: pointSize, scale: 1)
            .write(to: menuBarDir.appendingPathComponent("\(name).png"))
        try makeTemplatePNG(glyph: glyph, pointSize: pointSize, scale: 2)
            .write(to: menuBarDir.appendingPathComponent("\(name)@2x.png"))
        print("menu bar:", name)
    }
}

func writeAppIcon() throws {
    try makeAppIconPNG(pixelSize: 1024)
        .write(to: appIconDir.appendingPathComponent("AppIcon-1024.png"))

    let iconset = appIconDir.appendingPathComponent("AppIcon.iconset")
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

    let sizes: [(Int, String)] = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]
    for (px, name) in sizes {
        try makeAppIconPNG(pixelSize: px).write(to: iconset.appendingPathComponent(name))
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = [
        "-c", "icns", iconset.path,
        "-o", appIconDir.appendingPathComponent("AppIcon.icns").path,
    ]
    try process.run()
    process.waitUntilExit()
    try? FileManager.default.removeItem(at: iconset)
    print("app icon: AppIcon.icns")
}

try writeMenuBarIcons()
try writeAppIcon()
print("done")
