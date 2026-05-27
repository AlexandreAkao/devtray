import Foundation
import DevTrayCore

public enum CronClipboardMatcher {
    public static func match(_ clipboard: String) -> ClipboardMatchScore? {
        let s = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = s.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard fields.count == 5 else { return nil }   // macros are one token → excluded
        if case .success = CronEngine.parse(s) { return ClipboardMatchScore(.weak) }
        return nil
    }
}
