import Foundation

/// Challenge-response handshake the Speed Editor requires before it will
/// report keys. Written from the publicly documented algorithm.
///
/// The device hands the host a 64-bit challenge. The low three bits select
/// a byte rotation count and a table entry; the response is the rotated
/// value mixed with a further rotation under a fixed mask, then XORed with
/// the selected table constant. One of two tables is used depending on the
/// parity of the rotated value against a fixed bit pattern.
public enum SpeedEditorAuth {
    static let evenTable: [UInt64] = [
        0x3ae1_206f_97c1_0bc8,
        0x2a9a_b32b_ebf2_44c6,
        0x20a6_f8b8_df9a_df0a,
        0xaf80_ece5_2cfc_1719,
        0xec2e_e2f7_414f_d151,
        0xb055_adfd_7334_4a15,
        0xa63d_2e30_5900_1187,
        0x751b_f623_f42e_0dde,
    ]

    static let oddTable: [UInt64] = [
        0x3e22_b34f_502e_7fde,
        0x2465_6b98_1875_ab1c,
        0xa17f_3456_df7b_f8c3,
        0x6df7_2e19_41ae_f698,
        0x7222_6f01_1e66_ab94,
        0x3831_a3c6_0629_6b42,
        0xfd7f_f818_8133_2c89,
        0x61a3_f647_4ff2_36c6,
    ]

    static let mask: UInt64 = 0xa79a_63f5_85d3_7bf0

    /// Rotate right by one byte.
    @inline(__always)
    static func rotateByte(_ v: UInt64) -> UInt64 {
        (v >> 8) | (v << 56)
    }

    /// Compute the response the device expects for `challenge`.
    public static func response(to challenge: UInt64) -> UInt64 {
        let n = Int(challenge & 7)
        var v = challenge
        for _ in 0..<n { v = rotateByte(v) }

        let key: UInt64
        if (v & 1) == ((0x78 >> UInt64(n)) & 1) {
            key = evenTable[n]
        } else {
            v ^= rotateByte(v)
            key = oddTable[n]
        }
        return v ^ (rotateByte(v) & mask) ^ key
    }
}
