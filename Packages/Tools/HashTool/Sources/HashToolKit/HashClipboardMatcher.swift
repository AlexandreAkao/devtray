import Foundation
import DevTrayCore

public enum HashClipboardMatcher {
    private static let validLengths: Set<Int> = [32, 40, 64, 128]

    public static func match(_ clipboard: String) -> ClipboardMatchScore? {
        let trimmed = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validLengths.contains(trimmed.count) else { return nil }
        let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        if trimmed.unicodeScalars.contains(where: { !hex.contains($0) }) {
            return nil
        }
        return ClipboardMatchScore(.weak)
    }
}
