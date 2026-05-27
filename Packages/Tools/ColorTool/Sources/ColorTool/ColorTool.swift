import SwiftUI
import DevTrayCore
import ColorToolKit

public enum ColorTool: Tool {
    public static let id: ToolID = "color"
    public static let displayName = "Color"
    public static let iconName = "paintpalette"
    public static let keywords = ["color", "colour", "hex", "rgb", "hsl", "picker"]
    public static let category: ToolCategory = .formatting

    @MainActor public static func makeView() -> AnyView {
        AnyView(ColorToolView())
    }
}

public extension ColorTool {
    static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
        ColorClipboardMatcher.match(clipboard)
    }
}
