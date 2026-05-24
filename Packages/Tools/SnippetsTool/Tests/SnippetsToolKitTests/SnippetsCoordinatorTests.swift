import XCTest
import DevTrayCore
@testable import SnippetsToolKit

final class SnippetsCoordinatorTests: XCTestCase {
    private func makeCoordinator() -> SnippetsCoordinator {
        SnippetsCoordinator(store: InMemorySnippetStore())
    }

    func test_create_assignsIDAndTimestamps_andPersists() async throws {
        let c = makeCoordinator()
        let now = Date(timeIntervalSince1970: 500)
        let created = try await c.create(title: "T", content: "C", language: "swift",
                                         tags: ["a"], isFavorite: false, now: now)
        XCTAssertFalse(created.id.isEmpty)
        XCTAssertEqual(created.createdAt, now)
        XCTAssertEqual(created.updatedAt, now)
        let loaded = try await c.load()
        XCTAssertEqual(loaded.map(\.id), [created.id])
    }

    func test_update_bumpsUpdatedAt() async throws {
        let c = makeCoordinator()
        var s = try await c.create(title: "T", content: "C", language: nil,
                                   tags: [], isFavorite: false,
                                   now: Date(timeIntervalSince1970: 1))
        s.title = "T2"
        let updated = try await c.update(s, now: Date(timeIntervalSince1970: 2))
        XCTAssertEqual(updated.title, "T2")
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 2))
    }

    func test_delete_removes() async throws {
        let c = makeCoordinator()
        let s = try await c.create(title: "T", content: "C", language: nil,
                                   tags: [], isFavorite: false, now: Date())
        try await c.delete(id: s.id)
        let loaded = try await c.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_toggleFavorite_flipsAndPersists() async throws {
        let c = makeCoordinator()
        let s = try await c.create(title: "T", content: "C", language: nil,
                                   tags: [], isFavorite: false, now: Date())
        let toggled = try await c.toggleFavorite(s, now: Date(timeIntervalSince1970: 9))
        XCTAssertTrue(toggled.isFavorite)
        let reloaded = try await c.load().first
        XCTAssertEqual(reloaded?.isFavorite, true)
    }

    func test_search_delegatesToStore() async throws {
        let c = makeCoordinator()
        _ = try await c.create(title: "Networking", content: "x", language: nil,
                               tags: [], isFavorite: false, now: Date())
        let hits = try await c.search("net")
        XCTAssertEqual(hits.map(\.title), ["Networking"])
    }

    func test_recordUse_incrementsUseCount() async throws {
        let c = makeCoordinator()
        let s = try await c.create(title: "T", content: "C", language: nil,
                                   tags: [], isFavorite: false, now: Date())
        try await c.recordUse(id: s.id)
        let reloaded = try await c.load().first
        XCTAssertEqual(reloaded?.useCount, 1)
    }
}
