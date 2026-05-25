import Foundation

public struct Snippet: Identifiable, Hashable, Sendable, Codable {
    public typealias ID = String

    public let id: ID
    public var title: String
    public var content: String
    public var language: String?
    public var tags: [String]
    public var isFavorite: Bool
    public let createdAt: Date
    public var updatedAt: Date
    public var useCount: Int
    public var lastUsedAt: Date?

    public init(
        id: ID,
        title: String,
        content: String,
        language: String? = nil,
        tags: [String] = [],
        isFavorite: Bool = false,
        createdAt: Date,
        updatedAt: Date,
        useCount: Int = 0,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.language = language
        self.tags = tags
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
    }
}
