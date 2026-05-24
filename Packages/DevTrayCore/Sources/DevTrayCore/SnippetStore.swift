import Foundation

public protocol SnippetStore: Sendable {
    /// Upsert by `id`.
    func save(_ snippet: Snippet) async throws
    func delete(id: Snippet.ID) async throws
    /// All snippets, ordered by `updatedAt` descending.
    func all() async throws -> [Snippet]
    /// Full-text search; empty/whitespace query returns `all()`.
    func search(_ query: String) async throws -> [Snippet]
    /// Increments `useCount` and stamps `lastUsedAt = now`.
    func incrementUseCount(id: Snippet.ID) async throws
}
