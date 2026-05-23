import Foundation
import DevTrayCore

public enum URLClipboardMatcher {
    public static func match(_ clipboard: String) -> ClipboardMatchScore? {
        let trimmed = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = trimmed.range(of: "://") else { return nil }
        let scheme = trimmed[..<separator.lowerBound]
        let rest = trimmed[separator.upperBound...]
        guard !scheme.isEmpty, !rest.isEmpty else { return nil }
        let schemeChars = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-.")
        if scheme.unicodeScalars.contains(where: { !schemeChars.contains($0) }) {
            return nil
        }
        return ClipboardMatchScore(.strong)
    }
}
