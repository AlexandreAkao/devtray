import DevTrayCore
import DiffToolKit
import SwiftUI

public enum DiffTool: Tool {
    public static let id: ToolID = "diff"
    public static let displayName = "Diff"
    public static let iconName = "plusminus"
    public static let keywords = ["diff", "compare", "difference", "text"]
    public static let category: ToolCategory = .text

    @MainActor public static func makeView() -> AnyView {
        AnyView(DiffToolView())
    }
}
