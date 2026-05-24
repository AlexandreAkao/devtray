import XCTest
@testable import DevTrayCore

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
}
