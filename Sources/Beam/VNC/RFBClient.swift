import Foundation
import CoreGraphics
import Combine

enum RFBState: Equatable {
    case idle
    case connecting
    case authenticating
    case connected
    case failed(String)
    case disconnected
}

/// A native RFB (VNC) client. Renders the remote framebuffer to a `CGImage`
/// and forwards pointer/keyboard input. Public state is published on the main
/// thread for SwiftUI.
final class RFBClient: ObservableObject {
    @Published private(set) var state: RFBState = .idle
    @Published private(set) var image: CGImage?
    @Published private(set) var remoteSize: CGSize = .zero
    @Published private(set) var desktopName: String = ""
    @Published private(set) var fps: Int = 0

    /// Remote cursor shape, rendered locally for zero-latency pointer feedback.
    @Published private(set) var cursorImage: CGImage?
    private(set) var cursorHotspot: CGPoint = .zero
    private(set) var cursorSize: CGSize = .zero

    let connection: Connection

    private var channel: ByteChannel?
    private var framebuffer: Framebuffer?
    private var tunnel: SSHTunnel?
    private var task: Task<Void, Never>?

    private var frameCounter = 0
    private var lastFPSStamp = Date()
    private var pointerMask: UInt8 = 0

    init(connection: Connection) {
        self.connection = connection
    }

    // MARK: Lifecycle

    func start() {
        guard task == nil else { return }
        task = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.run()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        channel?.close()
        channel = nil
        tunnel?.stop()
        tunnel = nil
        setState(.disconnected)
    }

    private func run() async {
        do {
            setState(.connecting)

            let host: String
            let port: UInt16
            if connection.useSSHTunnel {
                let t = SSHTunnel()
                try await t.start(connection: connection)
                tunnel = t
                host = "127.0.0.1"
                port = t.localPort
            } else {
                host = connection.host
                port = UInt16(connection.vncPort)
            }

            let ch = ByteChannel(host: host, port: port)
            try await ch.connect()
            channel = ch

            try await handshake(ch)
            try await authenticate(ch)
            try await initSession(ch)
            setState(.connected)
            try await messageLoop(ch)
        } catch is CancellationError {
            setState(.disconnected)
        } catch {
            // A cancel (user disconnect) closes the socket, which surfaces here
            // as a read error — treat that as a clean disconnect, not a failure.
            if Task.isCancelled {
                setState(.disconnected)
            } else {
                setState(.failed(error.localizedDescription))
            }
            channel?.close()
            tunnel?.stop()
        }
    }

    // MARK: Handshake & auth

    private func handshake(_ ch: ByteChannel) async throws {
        let version = try await ch.read(12)
        guard let str = String(data: version, encoding: .ascii), str.hasPrefix("RFB ") else {
            throw RFBError.handshakeFailed("Not a VNC server")
        }
        // Always speak 3.8.
        ch.send("RFB 003.008\n".data(using: .ascii)!)
    }

    private func authenticate(_ ch: ByteChannel) async throws {
        setState(.authenticating)
        let count = try await ch.readUInt8()
        if count == 0 {
            // Server refused; the reason string follows.
            let len = try await ch.readUInt32()
            let reason = try await ch.read(Int(len))
            throw RFBError.handshakeFailed(String(data: reason, encoding: .utf8) ?? "rejected")
        }
        let types = try await ch.read(Int(count))
        let supported = Set(types)

        if supported.contains(1) {
            ch.send(Data([1]))                // None
        } else if supported.contains(2) {
            ch.send(Data([2]))                // VNC auth
            let challenge = try await ch.read(16)
            ch.send(VNCAuth.response(challenge: challenge, password: connection.vncPassword))
        } else {
            throw RFBError.unsupported("No supported security type (server offered \(Array(supported)))")
        }

        let result = try await ch.readUInt32()
        if result != 0 {
            // 3.8 servers send a reason; tolerate servers that don't.
            var reason = "Authentication failed"
            if let len = try? await ch.readUInt32(),
               let data = try? await ch.read(Int(len)),
               let str = String(data: data, encoding: .utf8) {
                reason = str
            }
            throw RFBError.authFailed(reason)
        }
    }

    private func initSession(_ ch: ByteChannel) async throws {
        ch.send(Data([1]))                    // ClientInit: shared = true

        let width = Int(try await ch.readUInt16())
        let height = Int(try await ch.readUInt16())
        _ = try await ch.read(16)             // server pixel format (we override it)
        let nameLen = try await ch.readUInt32()
        guard nameLen <= 1 << 20 else { throw RFBError.handshakeFailed("Desktop name too large") }
        let nameData = try await ch.read(Int(nameLen))
        let name = String(data: nameData, encoding: .utf8) ?? ""

        let fb = Framebuffer(width: width, height: height)
        framebuffer = fb
        onMain {
            self.remoteSize = CGSize(width: width, height: height)
            self.desktopName = name
        }

        try await setPixelFormat(ch)
        try await setEncodings(ch)
        requestUpdate(ch, incremental: false)
    }

    private func setPixelFormat(_ ch: ByteChannel) async throws {
        var msg = Data()
        msg.appendU8(RFB.setPixelFormat)
        msg.append(contentsOf: [0, 0, 0])     // padding
        // 32bpp, depth 24, little-endian, true colour, R<<16 G<<8 B<<0.
        msg.appendU8(32)                       // bits-per-pixel
        msg.appendU8(24)                       // depth
        msg.appendU8(0)                        // big-endian flag
        msg.appendU8(1)                        // true colour
        msg.appendU16(255); msg.appendU16(255); msg.appendU16(255) // max R/G/B
        msg.appendU8(16); msg.appendU8(8); msg.appendU8(0)         // shifts R/G/B
        msg.append(contentsOf: [0, 0, 0])     // padding
        ch.send(msg)
    }

    private func setEncodings(_ ch: ByteChannel) async throws {
        let encodings: [Int32] = [RFB.encHextile, RFB.encCopyRect, RFB.encRaw, RFB.encCursor, RFB.encDesktopSize]
        var msg = Data()
        msg.appendU8(RFB.setEncodings)
        msg.appendU8(0)                        // padding
        msg.appendU16(UInt16(encodings.count))
        for e in encodings { msg.appendI32(e) }
        ch.send(msg)
    }

    private func requestUpdate(_ ch: ByteChannel, incremental: Bool) {
        guard let fb = framebuffer else { return }
        var msg = Data()
        msg.appendU8(RFB.framebufferUpdateRequest)
        msg.appendU8(incremental ? 1 : 0)
        msg.appendU16(0); msg.appendU16(0)
        msg.appendU16(UInt16(fb.width)); msg.appendU16(UInt16(fb.height))
        ch.send(msg)
    }

    // MARK: Server message loop

    private func messageLoop(_ ch: ByteChannel) async throws {
        while !Task.isCancelled {
            let type = try await ch.readUInt8()
            switch type {
            case RFB.framebufferUpdate:
                let changed = try await readFramebufferUpdate(ch)
                emitFrame()
                requestUpdate(ch, incremental: true)
                if changed == 0 {
                    // Server replied immediately with nothing — avoid a busy loop.
                    try? await Task.sleep(nanoseconds: 16_000_000)
                }
            case RFB.setColourMapEntries:
                _ = try await ch.readUInt8()                  // padding
                _ = try await ch.readUInt16()                 // first colour
                let n = Int(try await ch.readUInt16())
                _ = try await ch.read(n * 6)
            case RFB.bell:
                break
            case RFB.serverCutText:
                _ = try await ch.read(3)                      // padding
                let len = Int(try await ch.readUInt32())
                guard len <= 8 << 20 else { throw RFBError.unsupported("Cut text too large") }
                _ = try await ch.read(len)
            default:
                throw RFBError.unsupported("Unknown server message \(type)")
            }
        }
    }

    /// Returns the number of rectangles processed.
    private func readFramebufferUpdate(_ ch: ByteChannel) async throws -> Int {
        _ = try await ch.readUInt8()                          // padding
        let count = Int(try await ch.readUInt16())
        for _ in 0..<count {
            let x = Int(try await ch.readUInt16())
            let y = Int(try await ch.readUInt16())
            let w = Int(try await ch.readUInt16())
            let h = Int(try await ch.readUInt16())
            // Guard against absurd rectangle sizes (max real display is well under this).
            guard w <= 16384, h <= 16384 else {
                throw RFBError.unsupported("Rectangle too large (\(w)×\(h))")
            }
            let encoding = try await ch.readInt32()
            switch encoding {
            case RFB.encRaw:        try await decodeRaw(ch, x: x, y: y, w: w, h: h)
            case RFB.encCopyRect:   try await decodeCopyRect(ch, x: x, y: y, w: w, h: h)
            case RFB.encHextile:    try await decodeHextile(ch, x: x, y: y, w: w, h: h)
            case RFB.encCursor:     try await decodeCursor(ch, x: x, y: y, w: w, h: h)
            case RFB.encDesktopSize: handleDesktopSize(w: w, h: h)
            default:
                throw RFBError.unsupported("Encoding \(encoding)")
            }
        }
        return count
    }

    // MARK: Decoders

    private func decodeRaw(_ ch: ByteChannel, x: Int, y: Int, w: Int, h: Int) async throws {
        let data = try await ch.read(w * h * 4)
        framebuffer?.blit([UInt8](data), x: x, y: y, w: w, h: h)
    }

    private func decodeCopyRect(_ ch: ByteChannel, x: Int, y: Int, w: Int, h: Int) async throws {
        let srcX = Int(try await ch.readUInt16())
        let srcY = Int(try await ch.readUInt16())
        framebuffer?.copyRect(srcX: srcX, srcY: srcY, dstX: x, dstY: y, w: w, h: h)
    }

    private func decodeHextile(_ ch: ByteChannel, x: Int, y: Int, w: Int, h: Int) async throws {
        guard let fb = framebuffer else { return }
        var bg: [UInt8] = [0, 0, 0, 0]
        var fg: [UInt8] = [0, 0, 0, 0]

        var ty = 0
        while ty < h {
            let th = min(16, h - ty)
            var tx = 0
            while tx < w {
                let tw = min(16, w - tx)
                let sub = try await ch.readUInt8()

                if sub & 0x01 != 0 {                          // Raw tile
                    let data = try await ch.read(tw * th * 4)
                    fb.blit([UInt8](data), x: x + tx, y: y + ty, w: tw, h: th)
                } else {
                    if sub & 0x02 != 0 { bg = [UInt8](try await ch.read(4)) }
                    if sub & 0x04 != 0 { fg = [UInt8](try await ch.read(4)) }
                    fb.fill(bg, x: x + tx, y: y + ty, w: tw, h: th)

                    if sub & 0x08 != 0 {                      // AnySubrects
                        let n = Int(try await ch.readUInt8())
                        let coloured = sub & 0x10 != 0
                        for _ in 0..<n {
                            let color = coloured ? [UInt8](try await ch.read(4)) : fg
                            let xy = try await ch.readUInt8()
                            let wh = try await ch.readUInt8()
                            let sx = Int(xy >> 4), sy = Int(xy & 0x0f)
                            let sw = Int(wh >> 4) + 1, sh = Int(wh & 0x0f) + 1
                            fb.fill(color, x: x + tx + sx, y: y + ty + sy, w: sw, h: sh)
                        }
                    }
                }
                tx += 16
            }
            ty += 16
        }
    }

    private func handleDesktopSize(w: Int, h: Int) {
        framebuffer?.resize(width: w, height: h)
        onMain { self.remoteSize = CGSize(width: w, height: h) }
    }

    /// Cursor pseudo-encoding: the server sends the cursor shape + 1-bpp mask
    /// instead of baking it into the framebuffer, so we render it locally.
    private func decodeCursor(_ ch: ByteChannel, x: Int, y: Int, w: Int, h: Int) async throws {
        if w == 0 || h == 0 {
            onMain { self.cursorImage = nil }
            return
        }
        guard w <= 256, h <= 256 else { throw RFBError.unsupported("Cursor too large") }
        let colors = [UInt8](try await ch.read(w * h * 4))    // [B,G,R,x] per pixel
        let maskRow = (w + 7) / 8
        let mask = [UInt8](try await ch.read(maskRow * h))

        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        for row in 0..<h {
            for col in 0..<w {
                let i = row * w + col
                let opaque = (mask[row * maskRow + (col >> 3)] >> (7 - (col & 7))) & 1
                rgba[i * 4 + 0] = colors[i * 4 + 2]           // R
                rgba[i * 4 + 1] = colors[i * 4 + 1]           // G
                rgba[i * 4 + 2] = colors[i * 4 + 0]           // B
                rgba[i * 4 + 3] = opaque == 1 ? 255 : 0       // A
            }
        }

        let image = makeCursorImage(rgba, w: w, h: h)
        onMain {
            self.cursorHotspot = CGPoint(x: x, y: y)
            self.cursorSize = CGSize(width: w, height: h)
            self.cursorImage = image
        }
    }

    private func makeCursorImage(_ rgba: [UInt8], w: Int, h: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(
            width: w, height: h,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    // MARK: Frame emission

    private func emitFrame() {
        guard let image = framebuffer?.makeImage() else { return }
        frameCounter += 1
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFPSStamp)
        var fpsValue: Int?
        if elapsed >= 1 {
            fpsValue = Int(Double(frameCounter) / elapsed)
            frameCounter = 0
            lastFPSStamp = now
        }
        onMain {
            self.image = image
            if let f = fpsValue { self.fps = f }
        }
    }

    // MARK: Input

    func sendPointer(x: Int, y: Int, buttons: UInt8) {
        guard !connection.viewOnly, let ch = channel, case .connected = state else { return }
        pointerMask = buttons
        let cx = UInt16(clamping: max(0, min(x, Int(remoteSize.width) - 1)))
        let cy = UInt16(clamping: max(0, min(y, Int(remoteSize.height) - 1)))
        var msg = Data()
        msg.appendU8(RFB.pointerEvent)
        msg.appendU8(buttons)
        msg.appendU16(cx); msg.appendU16(cy)
        ch.send(msg)
    }

    /// Send a wheel "click" (button 4 = up, 5 = down) as press+release at `(x,y)`.
    func sendScroll(x: Int, y: Int, up: Bool) {
        guard !connection.viewOnly else { return }
        let bit: UInt8 = up ? 0x08 : 0x10
        sendPointer(x: x, y: y, buttons: pointerMask | bit)
        sendPointer(x: x, y: y, buttons: pointerMask & ~bit)
    }

    func sendKey(_ keysym: UInt32, down: Bool) {
        guard !connection.viewOnly, let ch = channel, case .connected = state else { return }
        var msg = Data()
        msg.appendU8(RFB.keyEvent)
        msg.appendU8(down ? 1 : 0)
        msg.appendU16(0)
        msg.appendU32(keysym)
        ch.send(msg)
    }

    // MARK: Helpers

    private func setState(_ s: RFBState) { onMain { self.state = s } }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
}
