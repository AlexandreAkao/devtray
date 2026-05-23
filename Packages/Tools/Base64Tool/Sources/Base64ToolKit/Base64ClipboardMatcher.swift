import Foundation
import DevTrayCore

public enum Base64ClipboardMatcher {
    public static func match(_ clipboard: String) -> ClipboardMatchScore? {
        let trimmed = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8, trimmed.count % 4 == 0 else { return nil }
        if trimmed.contains(".") { return nil }
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return nil
        }
        return ClipboardMatchScore(.weak)
    }
}
