import SwiftUI

public struct AnyTool: Identifiable, Hashable, Sendable {
    public let id: ToolID
    public let displayName: String
    public let iconName: String
    public let keywords: [String]
    public let category: ToolCategory

    private let _makeView: @MainActor @Sendable () -> AnyView

    public init<T: Tool>(_ tool: T.Type) {
        self.id = T.id
        self.displayName = T.displayName
        self.iconName = T.iconName
        self.keywords = T.keywords
        self.category = T.category
        self._makeView = { T.makeView() }
    }

    @MainActor public func makeView() -> AnyView {
        _makeView()
    }

    public static func == (lhs: AnyTool, rhs: AnyTool) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
