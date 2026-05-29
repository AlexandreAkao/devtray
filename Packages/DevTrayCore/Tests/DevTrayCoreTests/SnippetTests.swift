@testable import DevTrayCore
import XCTest

final class SnippetTests: XCTestCase {
    func test_init_appliesDefaults() {
        let now = Date()
        let s = Snippet(id: "a", title: "T", content: "C", createdAt: now, updatedAt: now)
        XCTAssertNil(s.language)
        XCTAssertEqual(s.tags, [])
        XCTAssertFalse(s.isFavorite)
        XCTAssertEqual(s.useCount, 0)
        XCTAssertNil(s.lastUsedAt)
    }

    func test_isMutableWhereExpected() {
        let now = Date()
        var s = Snippet(id: "a", title: "T", content: "C", createdAt: now, updatedAt: now)
        s.title = "T2"
        s.isFavorite = true
        s.tags = ["swift"]
        XCTAssertEqual(s.title, "T2")
        XCTAssertTrue(s.isFavorite)
        XCTAssertEqual(s.tags, ["swift"])
    }

    func test_equatable_byValue() {
        let now = Date()
        let a = Snippet(id: "x", title: "T", content: "C", createdAt: now, updatedAt: now)
        let b = Snippet(id: "x", title: "T", content: "C", createdAt: now, updatedAt: now)
        XCTAssertEqual(a, b)
    }

    func test_codable_roundTrips_allFields() throws {
        let original = Snippet(
            id: "abc",
            title: "Title",
            content: "let x = 1",
            language: "swift",
            tags: ["a", "b"],
            isFavorite: true,
            createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: Date(timeIntervalSince1970: 2000),
            useCount: 7,
            lastUsedAt: Date(timeIntervalSince1970: 3000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Snippet.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
