import SwiftUI
import AppKit

/// SwiftUI bridge to the AppKit surface that renders the framebuffer and
/// captures pointer/keyboard input.
struct VNCScreenView: NSViewRepresentable {
    @ObservedObject var client: RFBClient

    func makeNSView(context: Context) -> RemoteScreenNSView {
        let view = RemoteScreenNSView()
        view.client = client
        return view
    }

    func updateNSView(_ nsView: RemoteScreenNSView, context: Context) {
        nsView.client = client
        nsView.setImage(client.image)
        nsView.updateCursor(image: client.cursorImage,
                            hotspot: client.cursorHotspot,
                            size: client.cursorSize)
    }
}

final class RemoteScreenNSView: NSView {
    weak var client: RFBClient?

    private var currentButtons: UInt8 = 0
    private var lastFlags: NSEvent.ModifierFlags = []
    private var trackingArea: NSTrackingArea?
    private var remoteCursor: NSCursor?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.contentsGravity = .resizeAspect
        layer?.magnificationFilter = .trilinear
        // Avoid implicit cross-fade animations when a new frame arrives.
        layer?.actions = ["contents": NSNull()]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func setImage(_ image: CGImage?) {
        layer?.contents = image
    }

    /// Adopt the remote cursor shape so it tracks the local pointer with no lag.
    func updateCursor(image: CGImage?, hotspot: CGPoint, size: CGSize) {
        if let image, size.width > 0, size.height > 0 {
            let ns = NSImage(cgImage: image, size: NSSize(width: size.width, height: size.height))
            remoteCursor = NSCursor(image: ns, hotSpot: NSPoint(x: hotspot.x, y: hotspot.y))
        } else {
            remoteCursor = nil
        }
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        if let remoteCursor {
            addCursorRect(bounds, cursor: remoteCursor)
        } else {
            super.resetCursorRects()
        }
    }

    // MARK: Responder

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate],
            owner: self, userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    // MARK: Coordinate mapping (view points -> remote pixels, aspect-fit)

    private func remotePoint(_ event: NSEvent) -> (Int, Int)? {
        guard let client, client.remoteSize.width > 0, client.remoteSize.height > 0 else { return nil }
        let rw = client.remoteSize.width
        let rh = client.remoteSize.height
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(size.width / rw, size.height / rh)
        let dispW = rw * scale, dispH = rh * scale
        let ox = (size.width - dispW) / 2
        let oy = (size.height - dispH) / 2

        let p = convert(event.locationInWindow, from: nil)
        let relX = (p.x - ox) / scale
        let relYFromBottom = (p.y - oy) / scale
        let x = Int(relX.rounded())
        let y = Int((rh - relYFromBottom).rounded())   // flip: AppKit y is bottom-up
        return (x, y)
    }

    private func sendPointer(_ event: NSEvent) {
        if let remoteCursor { remoteCursor.set() }
        guard let (x, y) = remotePoint(event) else { return }
        client?.sendPointer(x: x, y: y, buttons: currentButtons)
    }

    override func cursorUpdate(with event: NSEvent) {
        if let remoteCursor { remoteCursor.set() } else { super.cursorUpdate(with: event) }
    }

    // MARK: Mouse

    override func mouseMoved(with event: NSEvent)        { sendPointer(event) }
    override func mouseDragged(with event: NSEvent)      { sendPointer(event) }
    override func rightMouseDragged(with event: NSEvent) { sendPointer(event) }
    override func otherMouseDragged(with event: NSEvent) { sendPointer(event) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        currentButtons |= 0x01; sendPointer(event)
    }
    override func mouseUp(with event: NSEvent)       { currentButtons &= ~0x01; sendPointer(event) }
    override func rightMouseDown(with event: NSEvent){ currentButtons |= 0x04; sendPointer(event) }
    override func rightMouseUp(with event: NSEvent)  { currentButtons &= ~0x04; sendPointer(event) }
    override func otherMouseDown(with event: NSEvent){ currentButtons |= 0x02; sendPointer(event) }
    override func otherMouseUp(with event: NSEvent)  { currentButtons &= ~0x02; sendPointer(event) }

    override func scrollWheel(with event: NSEvent) {
        guard let (x, y) = remotePoint(event) else { return }
        if event.deltaY != 0 { client?.sendScroll(x: x, y: y, up: event.deltaY > 0) }
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if let keysym = Keysyms.keysym(for: event) { client?.sendKey(keysym, down: true) }
    }

    override func keyUp(with event: NSEvent) {
        if let keysym = Keysyms.keysym(for: event) { client?.sendKey(keysym, down: false) }
    }

    override func flagsChanged(with event: NSEvent) {
        let flags = event.modifierFlags
        let mapCmdToCtrl = client?.connection.mapCommandToControl ?? true

        func update(_ flag: NSEvent.ModifierFlags, _ keysym: UInt32) {
            let now = flags.contains(flag)
            let was = lastFlags.contains(flag)
            if now != was { client?.sendKey(keysym, down: now) }
        }
        update(.shift, Keysyms.shiftL)
        update(.control, Keysyms.controlL)
        update(.option, Keysyms.altL)
        update(.command, mapCmdToCtrl ? Keysyms.controlL : Keysyms.superL)
        lastFlags = flags
    }

    /// Forward ⌘-combinations to the remote, but let macOS keep a few
    /// essential window/app shortcuts (Quit, Close, Minimise, Hide, Settings).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        guard event.modifierFlags.contains(.command) else { return false }

        let onlyCommand = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask) == .command
        if onlyCommand,
           let c = event.charactersIgnoringModifiers?.lowercased(),
           ["q", "w", "m", "h", ","].contains(c) {
            return false
        }
        if let keysym = Keysyms.keysym(for: event) {
            client?.sendKey(keysym, down: true)
            client?.sendKey(keysym, down: false)
            return true
        }
        return false
    }
}
