import Foundation
import DevTrayCore

/// UI-agnostic orchestration over a `SnippetStore`. Owns the rules for assigning
/// ids/timestamps and toggling favorites, so the view model stays thin and these
/// rules are testable without SwiftUI.
public struct SnippetsCoordinator: Sendable {
    private let store: any SnippetStore

    public init(store: any SnippetStore) {
        self.store = store
    }

    public func load() async throws -> [Snippet] {
        try await store.all()
    }

    public func search(_ query: String) async throws -> [Snippet] {
        try await store.search(query)
    }

    /// Creates a snippet with a fresh UUID and `createdAt == updatedAt == now`,
    /// persists it, and returns it.
    public func create(title: String, content: String, language: String?,
                       tags: [String], isFavorite: Bool, now: Date) async throws -> Snippet {
        let snippet = Snippet(
            id: UUID().uuidString,
            title: title,
            content: content,
            language: language,
            tags: tags,
            isFavorite: isFavorite,
            createdAt: now,
            updatedAt: now
        )
        try await store.save(snippet)
        return snippet
    }

    /// Persists edits to an existing snippet, bumping `updatedAt` to `now`.
    public func update(_ snippet: Snippet, now: Date) async throws -> Snippet {
        var edited = snippet
        edited.updatedAt = now
        try await store.save(edited)
        return edited
    }

    public func delete(id: Snippet.ID) async throws {
        try await store.delete(id: id)
    }

    public func toggleFavorite(_ snippet: Snippet, now: Date) async throws -> Snippet {
        var edited = snippet
        edited.isFavorite.toggle()
        edited.updatedAt = now
        try await store.save(edited)
        return edited
    }

    public func recordUse(id: Snippet.ID) async throws {
        try await store.incrementUseCount(id: id)
    }
}
