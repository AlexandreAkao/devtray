import XCTest
@testable import DevTrayCore

final class InMemorySnippetStoreTests: XCTestCase {
    private func snippet(_ id: String, _ title: String, content: String = "",
                         tags: [String] = [], updated: Date = Date()) -> Snippet {
        Snippet(id: id, title: title, content: content, tags: tags,
                createdAt: updated, updatedAt: updated)
    }

    func test_saveThenAll_returnsSnippet() async throws {
        let store = InMemorySnippetStore()
        try await store.save(snippet("a", "Title"))
        let all = try await store.all()
        XCTAssertEqual(all.map(\.id), ["a"])
    }

    func test_save_sameID_upserts() async throws {
        let store = InMemorySnippetStore()
        try await store.save(snippet("a", "One"))
        try await store.save(snippet("a", "Two"))
        let all = try await store.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.title, "Two")
    }

    func test_all_ordersByUpdatedDescending() async throws {
        let store = InMemorySnippetStore()
        let old = Date(timeIntervalSince1970: 100)
        let new = Date(timeIntervalSince1970: 200)
        try await store.save(snippet("old", "Old", updated: old))
        try await store.save(snippet("new", "New", updated: new))
        let all = try await store.all()
        XCTAssertEqual(all.map(\.id), ["new", "old"])
    }

    func test_delete_removes() async throws {
        let store = InMemorySnippetStore()
        try await store.save(snippet("a", "Title"))
        try await store.delete(id: "a")
        let all = try await store.all()
        XCTAssertTrue(all.isEmpty)
    }

    func test_search_matchesTitleContentAndTags_caseInsensitive() async throws {
        let store = InMemorySnippetStore()
        try await store.save(snippet("t", "Hello World"))
        try await store.save(snippet("c", "Other", content: "needle inside"))
        try await store.save(snippet("g", "Other2", tags: ["Swift"]))
        let byTitle = try await store.search("hello")
        let byContent = try await store.search("NEEDLE")
        let byTag = try await store.search("swift")
        XCTAssertEqual(byTitle.map(\.id), ["t"])
        XCTAssertEqual(byContent.map(\.id), ["c"])
        XCTAssertEqual(byTag.map(\.id), ["g"])
    }

    func test_search_emptyQuery_returnsAll() async throws {
        let store = InMemorySnippetStore()
        try await store.save(snippet("a", "A"))
        try await store.save(snippet("b", "B"))
        let all = try await store.search("   ")
        XCTAssertEqual(all.count, 2)
    }

    func test_incrementUseCount_incrementsAndStampsLastUsed() async throws {
        let store = InMemorySnippetStore()
        try await store.save(snippet("a", "A"))
        try await store.incrementUseCount(id: "a")
        let s = try await store.all().first
        XCTAssertEqual(s?.useCount, 1)
        XCTAssertNotNil(s?.lastUsedAt)
    }
}
