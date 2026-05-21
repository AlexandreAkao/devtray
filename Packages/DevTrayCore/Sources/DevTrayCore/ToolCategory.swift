public enum ToolCategory: String, Equatable, CaseIterable, Sendable, Codable {
    case encoding
    case formatting
    case crypto
    case storage
    case time
    case text

    public var displayName: String {
        switch self {
        case .encoding:   return "Encoding"
        case .formatting: return "Formatting"
        case .crypto:     return "Crypto"
        case .storage:    return "Storage"
        case .time:       return "Time"
        case .text:       return "Text"
        }
    }
}
