import SwiftUI
import DevTrayCore

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
