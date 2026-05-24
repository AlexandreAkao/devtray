import XCTest
@testable import DevTrayStorage
import DevTrayCore
import GRDB

final class SQLiteSnippetStoreTests: XCTestCase {
    private func makeStore() throws -> SQLiteSnippetStore {
        let queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(on: &migrator)
        try migrator.migrate(queue)
        return SQLiteSnippetStore(dbQueue: queue)
    }

    private func snippet(_ id: String, title: String, content: String = "body",
                         language: String? = "swift", tags: [String] = ["t"],
                         favorite: Bool = false,
                         updated: Date = Date(timeIntervalSince1970: 1000)) -> Snippet {
        Snippet(id: id, title: title, content: content, language: language,
                tags: tags, isFavorite: favorite,
                createdAt: Date(timeIntervalSince1970: 1), updatedAt: updated)
    }

    func test_save_thenAll_roundTripsAllFields() async throws {
        let store = try makeStore()
        try await store.save(snippet("a", title: "Hello", tags: ["x", "y"], favorite: true))
        let all = try await store.all()
        let s = try XCTUnwrap(all.first)
        XCTAssertEqual(s.id, "a")
        XCTAssertEqual(s.title, "Hello")
        XCTAssertEqual(s.content, "body")
        XCTAssertEqual(s.language, "swift")
        XCTAssertEqual(s.tags, ["x", "y"])
        XCTAssertTrue(s.isFavorite)
        XCTAssertEqual(s.useCount, 0)
        XCTAssertNil(s.lastUsedAt)
    }

    func test_save_nilLanguage_roundTrips() async throws {
        let store = try makeStore()
        try await store.save(snippet("a", title: "T", language: nil))
        let all = try await store.all()
        let s = try XCTUnwrap(all.first)
        XCTAssertNil(s.language)
    }

    func test_save_sameID_upsertsNotDuplicates() async throws {
        let store = try makeStore()
        try await store.save(snippet("a", title: "One"))
        try await store.save(snippet("a", title: "Two"))
        let all = try await store.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.title, "Two")
    }

    func test_all_ordersByUpdatedDescending() async throws {
        let store = try makeStore()
        try await store.save(snippet("old", title: "Old", updated: Date(timeIntervalSince1970: 100)))
        try await store.save(snippet("new", title: "New", updated: Date(timeIntervalSince1970: 200)))
        let all = try await store.all()
        XCTAssertEqual(all.map(\.id), ["new", "old"])
    }

    func test_delete_removesRow() async throws {
        let store = try makeStore()
        try await store.save(snippet("a", title: "T"))
        try await store.delete(id: "a")
        let all = try await store.all()
        XCTAssertTrue(all.isEmpty)
    }

    func test_search_findsByTitleContentAndTags() async throws {
        let store = try makeStore()
        try await store.save(snippet("t", title: "Hello World", content: "x", tags: []))
        try await store.save(snippet("c", title: "Other", content: "needle inside", tags: []))
        try await store.save(snippet("g", title: "Third", content: "x", tags: ["swiftui"]))
        let helloResults = try await store.search("hello")
        let needleResults = try await store.search("needle")
        let swiftuiResults = try await store.search("swiftui")
        XCTAssertEqual(helloResults.map(\.id), ["t"])
        XCTAssertEqual(needleResults.map(\.id), ["c"])
        XCTAssertEqual(swiftuiResults.map(\.id), ["g"])
    }

    func test_search_prefixMatch() async throws {
        let store = try makeStore()
        try await store.save(snippet("a", title: "Networking", content: "x", tags: []))
        let results = try await store.search("net")
        XCTAssertEqual(results.map(\.id), ["a"])
    }

    func test_search_reflectsUpdate() async throws {
        let store = try makeStore()
        var s = snippet("a", title: "Alpha", content: "hello", tags: [])
        try await store.save(s)
        s.content = "world"
        try await store.save(s)
        let helloResults = try await store.search("hello")
        let worldResults = try await store.search("world")
        XCTAssertTrue(helloResults.isEmpty)
        XCTAssertEqual(worldResults.map(\.id), ["a"])
    }

    func test_search_reflectsDelete() async throws {
        let store = try makeStore()
        try await store.save(snippet("a", title: "Findme", content: "x", tags: []))
        try await store.delete(id: "a")
        let results = try await store.search("findme")
        XCTAssertTrue(results.isEmpty)
    }

    func test_search_emptyQuery_returnsAll() async throws {
        let store = try makeStore()
        try await store.save(snippet("a", title: "A"))
        try await store.save(snippet("b", title: "B"))
        let results = try await store.search("  ")
        XCTAssertEqual(results.count, 2)
    }

    func test_incrementUseCount_incrementsAndStamps() async throws {
        let store = try makeStore()
        try await store.save(snippet("a", title: "A"))
        try await store.incrementUseCount(id: "a")
        let all = try await store.all()
        let s = try XCTUnwrap(all.first)
        XCTAssertEqual(s.useCount, 1)
        XCTAssertNotNil(s.lastUsedAt)
    }
}
