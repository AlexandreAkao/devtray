import DevTrayCore
import Foundation
import Security

public enum UUIDEngine {
    public static let minCount = 1
    public static let maxCount = 50

    public static func generate(format: IDFormat, count: Int) -> Result<[String], ToolError> {
        guard count >= minCount, count <= maxCount else {
            return .failure(.invalidInput(
                reason: "Count must be between \(minCount) and \(maxCount)"
            ))
        }
        var out: [String] = []
        out.reserveCapacity(count)
        for _ in 0 ..< count {
            switch format {
            case .uuidV4: out.append(generateV4())
            case .uuidV7: out.append(generateV7())
            case .ulid: out.append(generateULID())
            }
        }
        return .success(out)
    }

    // MARK: - v4 (Foundation)

    private static func generateV4() -> String {
        UUID().uuidString.lowercased()
    }

    // MARK: - v7 (RFC 9562)

    private static func generateV7() -> String {
        let ms = UInt64(Date().timeIntervalSince1970 * 1000)
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, 16, &bytes)
        // First 6 bytes = 48-bit big-endian timestamp (unix ms)
        bytes[0] = UInt8((ms >> 40) & 0xff)
        bytes[1] = UInt8((ms >> 32) & 0xff)
        bytes[2] = UInt8((ms >> 24) & 0xff)
        bytes[3] = UInt8((ms >> 16) & 0xff)
        bytes[4] = UInt8((ms >> 8) & 0xff)
        bytes[5] = UInt8(ms & 0xff)
        // Byte 6: version 0x7 in high nibble, keep random low nibble
        bytes[6] = (bytes[6] & 0x0f) | 0x70
        // Byte 8: variant 0b10 in top two bits
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return formatUUIDBytes(bytes)
    }

    private static func formatUUIDBytes(_ b: [UInt8]) -> String {
        String(
            format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            b[0], b[1], b[2], b[3],
            b[4], b[5],
            b[6], b[7],
            b[8], b[9],
            b[10], b[11], b[12], b[13], b[14], b[15]
        )
    }

    // MARK: - ULID

    private static let crockford: [Character] = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    private static func generateULID() -> String {
        let ms = UInt64(Date().timeIntervalSince1970 * 1000)
        var random = [UInt8](repeating: 0, count: 10)
        _ = SecRandomCopyBytes(kSecRandomDefault, 10, &random)

        // Encode 48-bit timestamp into 10 Crockford chars (5 bits each, high → low)
        var ts = ""
        for i in (0 ..< 10).reversed() {
            let shift = i * 5
            let idx = Int((ms >> shift) & 0x1f)
            ts.append(crockford[idx])
        }

        // Encode 80 random bits (10 bytes) into 16 Crockford chars (5 bits each).
        // Stream bytes through a small buffer, emit 5 bits at a time.
        var buffer: UInt64 = 0
        var bufferBits = 0
        var randChars: [Character] = []
        randChars.reserveCapacity(16)
        for byte in random {
            buffer = (buffer << 8) | UInt64(byte)
            bufferBits += 8
            while bufferBits >= 5 {
                bufferBits -= 5
                let idx = Int((buffer >> bufferBits) & 0x1f)
                randChars.append(crockford[idx])
            }
        }
        // After 10 bytes (80 bits) exactly 16 chars are emitted; bufferBits == 0.
        return ts + String(randChars)
    }
}
