import Foundation

public actor InMemorySnippetStore: SnippetStore {
    private var snippets: [Snippet.ID: Snippet] = [:]

    public init() {}

    public func save(_ snippet: Snippet) async throws {
        snippets[snippet.id] = snippet
    }

    public func delete(id: Snippet.ID) async throws {
        snippets[id] = nil
    }

    public func all() async throws -> [Snippet] {
        snippets.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func search(_ query: String) async throws -> [Snippet] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return try await all() }
        return try await all().filter { snippet in
            snippet.title.lowercased().contains(q)
                || snippet.content.lowercased().contains(q)
                || snippet.tags.contains { $0.lowercased().contains(q) }
        }
    }

    public func incrementUseCount(id: Snippet.ID) async throws {
        guard var snippet = snippets[id] else { return }
        snippet.useCount += 1
        snippet.lastUsedAt = Date()
        snippets[id] = snippet
    }
}
