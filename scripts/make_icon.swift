// Generates AppIcon.iconset (PNGs at every required size) for Beam.
// A floating white screen panel showing a broadcast/signal glyph, on a deep
// indigo→violet gradient with a soft top-left glow — "beaming a remote screen".
//
// Usage: swift scripts/make_icon.swift <output.iconset-dir>
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func render(_ N: Int) -> CGImage {
    let S = CGFloat(N)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: N, height: N, bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)

    let margin = S * 0.085
    let rect = CGRect(x: margin, y: margin, width: S - 2 * margin, height: S - 2 * margin)
    let side = rect.width
    let radius = side * 0.2237
    let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Drop shadow for the whole tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.012), blur: S * 0.04,
                  color: rgb(0, 0, 0, 0.30))
    ctx.addPath(squircle); ctx.setFillColor(rgb(0, 0, 0)); ctx.fillPath()
    ctx.restoreGState()

    // Background: diagonal indigo→violet gradient + top-left glow.
    ctx.saveGState()
    ctx.addPath(squircle); ctx.clip()
    let g = CGGradient(colorsSpace: cs,
                       colors: [rgb(0.42, 0.45, 0.98), rgb(0.49, 0.27, 0.85)] as CFArray,
                       locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    let glow = CGGradient(colorsSpace: cs,
                          colors: [rgb(1, 1, 1, 0.28), rgb(1, 1, 1, 0)] as CFArray,
                          locations: [0, 1])!
    let glowCenter = CGPoint(x: rect.minX + side * 0.30, y: rect.maxY - side * 0.22)
    ctx.drawRadialGradient(glow, startCenter: glowCenter, startRadius: 0,
                           endCenter: glowCenter, endRadius: side * 0.75, options: [])
    ctx.restoreGState()

    // Subtle inner border highlight (glassy edge).
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect.insetBy(dx: S * 0.006, dy: S * 0.006),
                       cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setStrokeColor(rgb(1, 1, 1, 0.14)); ctx.setLineWidth(S * 0.008); ctx.strokePath()
    ctx.restoreGState()

    // Floating white screen panel.
    let screen = CGRect(x: rect.midX - 0.30 * side, y: rect.midY - 0.21 * side,
                        width: 0.60 * side, height: 0.42 * side)
    let screenPath = CGPath(roundedRect: screen, cornerWidth: side * 0.055,
                            cornerHeight: side * 0.055, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.018), blur: S * 0.045,
                  color: rgb(0.10, 0.08, 0.30, 0.35))
    ctx.addPath(screenPath); ctx.setFillColor(rgb(1, 1, 1)); ctx.fillPath()
    ctx.restoreGState()

    // Cursor / pointer glyph (deep indigo) on the screen — "remote control".
    let ink = rgb(0.31, 0.27, 0.90)
    // Classic arrow pointer, local coords (y-down), tip at (0,0), box 11×18.
    let pts: [(CGFloat, CGFloat)] = [
        (0, 0), (0, 16), (4, 12), (7, 18), (9, 17), (6, 11), (11, 11)
    ]
    let targetH = screen.height * 0.56
    let scale = targetH / 18.0
    let boxW = 11.0 * scale, boxH = 18.0 * scale
    let originX = screen.midX - boxW / 2
    let topY = screen.midY + boxH / 2
    let arrow = CGMutablePath()
    for (idx, p) in pts.enumerated() {
        let pt = CGPoint(x: originX + p.0 * scale, y: topY - p.1 * scale)
        if idx == 0 { arrow.move(to: pt) } else { arrow.addLine(to: pt) }
    }
    arrow.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.006), blur: S * 0.012,
                  color: rgb(0.10, 0.08, 0.30, 0.28))
    ctx.addPath(arrow); ctx.setFillColor(ink); ctx.fillPath()
    ctx.restoreGState()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let specs: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]
var cache: [Int: CGImage] = [:]
for (size, name) in specs {
    let image = cache[size] ?? render(size)
    cache[size] = image
    writePNG(image, to: outDir.appendingPathComponent("\(name).png"))
}
print("Wrote \(specs.count) icons to \(outDir.path)")
