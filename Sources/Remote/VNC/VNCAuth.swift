import Foundation
import CommonCrypto

/// VNC (RFB) DES authentication.
///
/// The password is truncated/padded to 8 bytes, each byte's bit order is
/// reversed (a long-standing quirk of the original VNC implementation), and the
/// 16-byte server challenge is DES/ECB-encrypted block by block.
enum VNCAuth {
    static func response(challenge: Data, password: String) -> Data {
        var key = [UInt8](repeating: 0, count: 8)
        let pw = Array(password.utf8.prefix(8))
        for i in 0..<pw.count { key[i] = reverseBits(pw[i]) }

        let outputCapacity = challenge.count
        var output = Data(count: outputCapacity)
        output.withUnsafeMutableBytes { outPtr in
            challenge.withUnsafeBytes { inPtr in
                key.withUnsafeBytes { keyPtr in
                    var moved = 0
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmDES),
                        CCOptions(kCCOptionECBMode),
                        keyPtr.baseAddress, 8,
                        nil,
                        inPtr.baseAddress, challenge.count,
                        outPtr.baseAddress, outputCapacity,
                        &moved
                    )
                }
            }
        }
        return output
    }

    private static func reverseBits(_ b: UInt8) -> UInt8 {
        var v = b
        var r: UInt8 = 0
        for _ in 0..<8 {
            r = (r << 1) | (v & 1)
            v >>= 1
        }
        return r
    }
}
