import DevTrayCore
import JWTToolKit
import SwiftUI

public enum JWTTool: Tool {
    public static let id: ToolID = "jwt"
    public static let displayName = "JWT"
    public static let iconName = "key.horizontal"
    public static let keywords = ["jwt", "token", "decode", "json web token"]
    public static let category: ToolCategory = .encoding

    @MainActor public static func makeView() -> AnyView {
        AnyView(JWTToolView())
    }
}

public extension JWTTool {
    static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
        JWTClipboardMatcher.match(clipboard)
    }
}
