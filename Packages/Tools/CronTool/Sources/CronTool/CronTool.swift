import SwiftUI
import DevTrayCore
import CronToolKit

public enum CronTool: Tool {
    public static let id: ToolID = "cron"
    public static let displayName = "Cron"
    public static let iconName = "clock.arrow.2.circlepath"
    public static let keywords = ["cron", "crontab", "schedule", "expression"]
    public static let category: ToolCategory = .time

    @MainActor public static func makeView() -> AnyView {
        AnyView(CronToolView())
    }
}

public extension CronTool {
    static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
        CronClipboardMatcher.match(clipboard)
    }
}
