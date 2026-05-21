import SwiftUI
import Combine

@MainActor
public final class ToolRegistry: ObservableObject {
    @Published public private(set) var tools: [AnyTool] = []

    public init() {}

    public func register<T: Tool>(_ tool: T.Type) {
        let anyTool = AnyTool(tool)
        guard !tools.contains(where: { $0.id == anyTool.id }) else { return }
        tools.append(anyTool)
    }

    public func find(byID id: ToolID) -> AnyTool? {
        tools.first { $0.id == id }
    }

    public func search(_ query: String) -> [AnyTool] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return tools }
        let needle = trimmed.lowercased()
        return tools.filter { tool in
            if tool.displayName.lowercased().contains(needle) { return true }
            return tool.keywords.contains { $0.lowercased().contains(needle) }
        }
    }
}
