import DevTrayCore
import SwiftUI

public enum RegexTool: Tool {
    public static let id: ToolID = "regex"
    public static let displayName = "Regex"
    public static let iconName = "magnifyingglass"
    public static let keywords = ["regex", "regexp", "pattern", "match", "replace"]
    public static let category: ToolCategory = .text

    @MainActor public static func makeView() -> AnyView {
        AnyView(RegexToolView())
    }
}
