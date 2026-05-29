import SwiftUI

public protocol Tool: Sendable {
    static var id: ToolID { get }
    static var displayName: String { get }
    static var iconName: String { get } // SF Symbol name, e.g. "key.horizontal"
    static var keywords: [String] { get } // for spotlight fuzzy search
    static var category: ToolCategory { get }

    @MainActor static func makeView() -> AnyView

    /// Tools can opt in to clipboard-driven promotion by overriding this. The default
    /// returns `nil` (no match).
    static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore?
}

public extension Tool {
    /// Default: tool does not declare a clipboard match. Override in conforming types
    /// to promote a tool when the clipboard contains a recognized format.
    static func clipboardMatch(_: String) -> ClipboardMatchScore? { nil }
}
