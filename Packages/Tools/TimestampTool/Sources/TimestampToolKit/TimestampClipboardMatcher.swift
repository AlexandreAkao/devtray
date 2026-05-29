import DevTrayCore
import Foundation

public enum TimestampClipboardMatcher {
    private static let minSeconds: Int64 = 978_307_200
    private static let maxSeconds: Int64 = 4_102_444_800

    public static func match(_ clipboard: String) -> ClipboardMatchScore? {
        let trimmed = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 10 || trimmed.count == 13 else { return nil }
        guard let value = Int64(trimmed) else { return nil }
        let seconds = trimmed.count == 13 ? value / 1000 : value
        guard seconds >= minSeconds, seconds <= maxSeconds else { return nil }
        return ClipboardMatchScore(.weak)
    }
}
