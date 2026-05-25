import XCTest
import Foundation
@testable import DevTrayCore

final class SnippetArchiveTests: XCTestCase {
    private func sample(id: String = "s1") -> Snippet {
        Snippet(
            id: id, title: "T", content: "C", language: "swift",
            tags: ["x"], isFavorite: true,
            createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: Date(timeIntervalSince1970: 2000),
            useCount: 3, lastUsedAt: Date(timeIntervalSince1970: 3000))
    }

    func test_encode_producesVersionedEnvelope() throws {
        let data = try SnippetArchive.encode([sample()], exportedAt: Date(timeIntervalSince1970: 5000))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertNotNil(json["exportedAt"])
        let snippets = try XCTUnwrap(json["snippets"] as? [[String: Any]])
        XCTAssertEqual(snippets.count, 1)
        XCTAssertEqual(snippets.first?["id"] as? String, "s1")
    }
}
