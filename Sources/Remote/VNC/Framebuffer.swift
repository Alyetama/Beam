import Foundation
import CoreGraphics

/// An in-memory framebuffer storing 32-bit pixels in `[B, G, R, x]` byte order,
/// which maps directly to a `CGImage` with `byteOrder32Little + noneSkipFirst`.
final class Framebuffer {
    private(set) var width: Int
    private(set) var height: Int
    private(set) var pixels: [UInt8]

    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let bitmapInfo = CGBitmapInfo(
        rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    )

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = [UInt8](repeating: 0, count: max(1, width * height * 4))
    }

    func resize(width newW: Int, height newH: Int) {
        guard newW > 0, newH > 0 else { return }
        width = newW
        height = newH
        pixels = [UInt8](repeating: 0, count: newW * newH * 4)
    }

    /// Copy a tightly-packed `w*h*4` block of `[B,G,R,x]` pixels into a region.
    func blit(_ src: [UInt8], x: Int, y: Int, w: Int, h: Int) {
        guard w > 0, h > 0 else { return }
        let rowBytes = w * 4
        pixels.withUnsafeMutableBytes { dst in
            src.withUnsafeBytes { srcPtr in
                for row in 0..<h {
                    let dy = y + row
                    guard dy >= 0, dy < height else { continue }
                    let dstOffset = (dy * width + x) * 4
                    let srcOffset = row * rowBytes
                    guard dstOffset >= 0, dstOffset + rowBytes <= dst.count else { continue }
                    memcpy(dst.baseAddress!.advanced(by: dstOffset),
                           srcPtr.baseAddress!.advanced(by: srcOffset),
                           rowBytes)
                }
            }
        }
    }

    /// Fill a rectangle with a single 4-byte pixel.
    func fill(_ pixel: [UInt8], x: Int, y: Int, w: Int, h: Int) {
        guard w > 0, h > 0, pixel.count == 4 else { return }
        pixels.withUnsafeMutableBytes { dst in
            let base = dst.baseAddress!
            for row in 0..<h {
                let dy = y + row
                guard dy >= 0, dy < height else { continue }
                for col in 0..<w {
                    let dx = x + col
                    guard dx >= 0, dx < width else { continue }
                    let off = (dy * width + dx) * 4
                    base.storeBytes(of: pixel[0], toByteOffset: off, as: UInt8.self)
                    base.storeBytes(of: pixel[1], toByteOffset: off + 1, as: UInt8.self)
                    base.storeBytes(of: pixel[2], toByteOffset: off + 2, as: UInt8.self)
                    base.storeBytes(of: pixel[3], toByteOffset: off + 3, as: UInt8.self)
                }
            }
        }
    }

    /// Copy a rectangle from one location to another (CopyRect encoding).
    func copyRect(srcX: Int, srcY: Int, dstX: Int, dstY: Int, w: Int, h: Int) {
        guard w > 0, h > 0 else { return }
        let rowBytes = w * 4
        var temp = [UInt8](repeating: 0, count: rowBytes * h)
        pixels.withUnsafeBytes { src in
            temp.withUnsafeMutableBytes { tmp in
                for row in 0..<h {
                    let sy = srcY + row
                    guard sy >= 0, sy < height else { continue }
                    let srcOff = (sy * width + srcX) * 4
                    guard srcOff >= 0, srcOff + rowBytes <= src.count else { continue }
                    memcpy(tmp.baseAddress!.advanced(by: row * rowBytes),
                           src.baseAddress!.advanced(by: srcOff), rowBytes)
                }
            }
        }
        blit(temp, x: dstX, y: dstY, w: w, h: h)
    }

    func makeImage() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: bitmapInfo,
            provider: provider, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent
        )
    }
}
