import SwiftUI
import DevTrayCore
import UUIDToolKit

public enum UUIDTool: Tool {
    public static let id: ToolID = "uuid"
    public static let displayName = "UUID / ULID"
    public static let iconName = "number.square"
    public static let keywords = ["uuid", "ulid", "guid", "id", "generate", "v4", "v7"]
    public static let category: ToolCategory = .generators

    @MainActor public static func makeView() -> AnyView {
        AnyView(UUIDToolView())
    }
}

public extension UUIDTool {
    static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
        UUIDClipboardMatcher.match(clipboard)
    }
}
