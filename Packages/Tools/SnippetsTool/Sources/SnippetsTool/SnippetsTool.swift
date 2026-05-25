import SwiftUI
import DevTrayCore
import SnippetsToolKit

public enum SnippetsTool: Tool {
    public static let id: ToolID = "snippets"
    public static let displayName = "Snippets"
    public static let iconName = "tray.full"
    public static let keywords = ["snippet", "snippets", "save", "store", "library", "code"]
    public static let category: ToolCategory = .storage

    @MainActor public static func makeView() -> AnyView {
        AnyView(SnippetsToolView())
    }
    // No clipboardMatch override: Snippets opts out of smart-paste (it is the
    // "navigate without preload" tool).
}
