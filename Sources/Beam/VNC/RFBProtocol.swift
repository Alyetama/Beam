import Foundation

extension Data {
    mutating func appendU8(_ v: UInt8) { append(v) }
    mutating func appendU16(_ v: UInt16) {
        append(UInt8(v >> 8)); append(UInt8(v & 0xff))
    }
    mutating func appendU32(_ v: UInt32) {
        append(UInt8((v >> 24) & 0xff)); append(UInt8((v >> 16) & 0xff))
        append(UInt8((v >> 8) & 0xff));  append(UInt8(v & 0xff))
    }
    mutating func appendI32(_ v: Int32) { appendU32(UInt32(bitPattern: v)) }
}

/// RFB protocol constants.
enum RFB {
    // Client -> server message types
    static let setPixelFormat: UInt8 = 0
    static let setEncodings: UInt8 = 2
    static let framebufferUpdateRequest: UInt8 = 3
    static let keyEvent: UInt8 = 4
    static let pointerEvent: UInt8 = 5

    // Server -> client message types
    static let framebufferUpdate: UInt8 = 0
    static let setColourMapEntries: UInt8 = 1
    static let bell: UInt8 = 2
    static let serverCutText: UInt8 = 3

    // Encodings
    static let encRaw: Int32 = 0
    static let encCopyRect: Int32 = 1
    static let encHextile: Int32 = 5
    static let encCursor: Int32 = -239        // client-side cursor rendering
    static let encDesktopSize: Int32 = -223
}
