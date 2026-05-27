import SwiftUI
import DevTrayCore
import YAMLToolKit

public enum YAMLTool: Tool {
    public static let id: ToolID = "yaml"
    public static let displayName = "YAML"
    public static let iconName = "arrow.left.arrow.right.square"
    public static let keywords = ["yaml", "yml", "json", "convert"]
    public static let category: ToolCategory = .formatting

    @MainActor public static func makeView() -> AnyView {
        AnyView(YAMLToolView())
    }
}
