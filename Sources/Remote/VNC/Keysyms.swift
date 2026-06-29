import AppKit

/// Maps macOS key events to X11 keysyms used by the RFB `KeyEvent` message.
enum Keysyms {
    // Common control keysyms.
    static let backspace: UInt32 = 0xff08
    static let tab: UInt32       = 0xff09
    static let `return`: UInt32  = 0xff0d
    static let escape: UInt32    = 0xff1b
    static let delete: UInt32    = 0xffff

    static let shiftL: UInt32    = 0xffe1
    static let controlL: UInt32  = 0xffe3
    static let altL: UInt32      = 0xffe9
    static let superL: UInt32    = 0xffeb

    /// Special, non-printable keys identified by hardware key code.
    private static let byKeyCode: [UInt16: UInt32] = [
        0x24: 0xff0d, // Return
        0x4C: 0xff8d, // Keypad Enter
        0x30: 0xff09, // Tab
        0x33: 0xff08, // Backspace
        0x35: 0xff1b, // Escape
        0x75: 0xffff, // Forward Delete
        0x73: 0xff50, // Home
        0x77: 0xff57, // End
        0x74: 0xff55, // Page Up
        0x79: 0xff56, // Page Down
        0x7B: 0xff51, // Left
        0x7C: 0xff53, // Right
        0x7E: 0xff52, // Up
        0x7D: 0xff54, // Down
        0x72: 0xff63, // Insert (Help)
        0x7A: 0xffbe, 0x78: 0xffbf, 0x63: 0xffc0, 0x76: 0xffc1, // F1–F4
        0x60: 0xffc2, 0x61: 0xffc3, 0x62: 0xffc4, 0x64: 0xffc5, // F5–F8
        0x65: 0xffc6, 0x6D: 0xffc7, 0x67: 0xffc8, 0x6F: 0xffc9  // F9–F12
    ]

    /// The keysym for a character-producing key event, or `nil` if it should be ignored.
    static func keysym(for event: NSEvent) -> UInt32? {
        if let special = byKeyCode[event.keyCode] { return special }
        guard let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first else { return nil }
        let value = scalar.value
        if value == 0 { return nil }
        if value < 0x20 {
            // Control characters: derive the base letter (e.g. Ctrl+C -> 'c').
            if value >= 1 && value <= 26 { return value + 0x60 }
            return nil
        }
        if value <= 0xff { return value }            // Latin-1 maps directly
        return 0x01000000 + value                    // Unicode keysym range
    }
}
