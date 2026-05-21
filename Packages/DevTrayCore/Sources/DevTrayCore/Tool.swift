import SwiftUI

public protocol Tool: Sendable {
    static var id: ToolID { get }
    static var displayName: String { get }
    static var iconName: String { get }           // SF Symbol name, e.g. "key.horizontal"
    static var keywords: [String] { get }         // for spotlight fuzzy search
    static var category: ToolCategory { get }

    @MainActor static func makeView() -> AnyView
}
