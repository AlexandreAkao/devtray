import DevTrayCore
import JSONToolKit
import SwiftUI

public enum JSONTool: Tool {
    public static let id: ToolID = "json"
    public static let displayName = "JSON"
    public static let iconName = "curlybraces"
    public static let keywords = ["json", "format", "pretty", "minify"]
    public static let category: ToolCategory = .formatting

    @MainActor public static func makeView() -> AnyView {
        AnyView(JSONToolView())
    }
}

public extension JSONTool {
    static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
        JSONClipboardMatcher.match(clipboard)
    }
}
