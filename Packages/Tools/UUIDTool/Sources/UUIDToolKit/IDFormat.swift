public enum IDFormat: String, CaseIterable, Sendable, Identifiable {
    case uuidV4
    case uuidV7
    case ulid

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .uuidV4: return "UUID v4"
        case .uuidV7: return "UUID v7"
        case .ulid: return "ULID"
        }
    }
}
