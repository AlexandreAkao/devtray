import DevTrayCore
import HashToolKit
import SwiftUI

public enum HashTool: Tool {
    public static let id: ToolID = "hash"
    public static let displayName = "Hash"
    public static let iconName = "lock.shield"
    public static let keywords = ["hash", "md5", "sha", "sha1", "sha256", "sha512", "digest"]
    public static let category: ToolCategory = .crypto

    @MainActor public static func makeView() -> AnyView {
        AnyView(HashToolView())
    }
}

public extension HashTool {
    static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
        HashClipboardMatcher.match(clipboard)
    }
}
