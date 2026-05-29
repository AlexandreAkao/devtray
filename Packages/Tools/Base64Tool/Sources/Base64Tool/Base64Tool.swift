import Base64ToolKit
import DevTrayCore
import SwiftUI

public enum Base64Tool: Tool {
    public static let id: ToolID = "base64"
    public static let displayName = "Base64"
    public static let iconName = "number"
    public static let keywords = ["base64", "encode", "decode"]
    public static let category: ToolCategory = .encoding

    @MainActor public static func makeView() -> AnyView {
        AnyView(Base64ToolView())
    }
}

public extension Base64Tool {
    static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
        Base64ClipboardMatcher.match(clipboard)
    }
}
