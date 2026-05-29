import DevTrayCore
import SwiftUI
import TimestampToolKit

public enum TimestampTool: Tool {
    public static let id: ToolID = "timestamp"
    public static let displayName = "Timestamp"
    public static let iconName = "clock"
    public static let keywords = ["timestamp", "epoch", "unix", "iso", "date", "time"]
    public static let category: ToolCategory = .time

    @MainActor public static func makeView() -> AnyView {
        AnyView(TimestampToolView())
    }
}

public extension TimestampTool {
    static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
        TimestampClipboardMatcher.match(clipboard)
    }
}
