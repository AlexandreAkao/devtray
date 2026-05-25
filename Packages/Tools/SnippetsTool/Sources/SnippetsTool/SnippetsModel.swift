import SwiftUI
import AppKit
import DevTrayCore
import SnippetsToolKit

@MainActor
@Observable
public final class SnippetsModel {
    public private(set) var snippets: [Snippet] = []
    public var query: String = ""
    public var showFavoritesOnly: Bool = false
    public private(set) var error: ToolError?
    public var selectedID: Snippet.ID?

    private let coordinator: SnippetsCoordinator

    public init(store: any SnippetStore) {
        self.coordinator = SnippetsCoordinator(store: store)
    }

    public var visibleSnippets: [Snippet] {
        showFavoritesOnly ? snippets.filter(\.isFavorite) : snippets
    }

    public var selectedSnippet: Snippet? {
        guard let selectedID else { return nil }
        return snippets.first { $0.id == selectedID }
    }

    public func reload() async {
        await run {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            snippets = trimmed.isEmpty
                ? try await coordinator.load()
                : try await coordinator.search(trimmed)
        }
    }

    public func createAndSelect() async {
        await run {
            let created = try await coordinator.create(
                title: "Untitled", content: "", language: nil,
                tags: [], isFavorite: false, now: .now)
            await reload()
            selectedID = created.id
        }
    }

    public func save(_ snippet: Snippet) async {
        await run {
            _ = try await coordinator.update(snippet, now: .now)
            await reload()
        }
    }

    public func delete(_ snippet: Snippet) async {
        await run {
            try await coordinator.delete(id: snippet.id)
            if selectedID == snippet.id { selectedID = nil }
            await reload()
        }
    }

    public func toggleFavorite(_ snippet: Snippet) async {
        await run {
            _ = try await coordinator.toggleFavorite(snippet, now: .now)
            await reload()
        }
    }

    public func copyToPasteboard(_ snippet: Snippet) async {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet.content, forType: .string)
        await run { try await coordinator.recordUse(id: snippet.id) }
    }

    private func run(_ work: () async throws -> Void) async {
        do {
            try await work()
            error = nil
        } catch let toolError as ToolError {
            error = toolError
        } catch {
            self.error = .storageFailure(message: error.localizedDescription)
        }
    }
}
