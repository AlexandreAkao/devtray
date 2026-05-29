import DevTrayCore
import Foundation

public enum UUIDClipboardMatcher {
    private static let uuid = try! NSRegularExpression(
        pattern: "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
    )
    private static let ulid = try! NSRegularExpression(
        pattern: "^[0-9A-HJKMNP-TV-Z]{26}$"
    )

    public static func match(_ clipboard: String) -> ClipboardMatchScore? {
        let trimmed = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        if uuid.firstMatch(in: trimmed, range: range) != nil
            || ulid.firstMatch(in: trimmed, range: range) != nil {
            return ClipboardMatchScore(.strong)
        }
        return nil
    }
}
