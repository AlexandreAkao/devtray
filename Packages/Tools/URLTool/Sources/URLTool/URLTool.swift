import DevTrayCore
import SwiftUI
import URLToolKit

public enum URLTool: Tool {
    public static let id: ToolID = "url"
    public static let displayName = "URL"
    public static let iconName = "link"
    public static let keywords = ["url", "uri", "percent", "encode", "decode"]
    public static let category: ToolCategory = .encoding

    @MainActor public static func makeView() -> AnyView {
        AnyView(URLToolView())
    }
}

public extension URLTool {
    static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
        URLClipboardMatcher.match(clipboard)
    }
}
