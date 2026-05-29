import DevTrayCore
import Foundation

public enum ColorClipboardMatcher {
    public static func match(_ clipboard: String) -> ClipboardMatchScore? {
        let s = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if case .success = ColorEngine.parse(s) { return ClipboardMatchScore(.strong) }
        return nil
    }
}
