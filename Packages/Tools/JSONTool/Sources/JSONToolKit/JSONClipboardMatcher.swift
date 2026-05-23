import Foundation
import DevTrayCore

public enum JSONClipboardMatcher {
    public static func match(_ clipboard: String) -> ClipboardMatchScore? {
        let trimmed = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, let last = trimmed.last else { return nil }
        let isObject = first == "{" && last == "}"
        let isArray = first == "[" && last == "]"
        guard isObject || isArray else { return nil }
        return ClipboardMatchScore(.strong)
    }
}
