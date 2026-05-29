import DevTrayCore
import Foundation

public enum JWTClipboardMatcher {
    public static func match(_ clipboard: String) -> ClipboardMatchScore? {
        let trimmed = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("eyJ") else { return nil }
        let segments = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else { return nil }
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        for segment in segments {
            if segment.isEmpty { return nil }
            if segment.unicodeScalars.contains(where: { !allowed.contains($0) }) {
                return nil
            }
        }
        return ClipboardMatchScore(.strong)
    }
}
