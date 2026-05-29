@testable import DevTrayCore
import Foundation
import XCTest

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
        XCTAssertEqual(json["exportedAt"] as? String, "1970-01-01T01:23:20Z")
        let snippets = try XCTUnwrap(json["snippets"] as? [[String: Any]])
        XCTAssertEqual(snippets.count, 1)
        XCTAssertEqual(snippets.first?["id"] as? String, "s1")
    }

    func test_decode_roundTripsAllFields() throws {
        let original = [sample(id: "a"), sample(id: "b")]
        let data = try SnippetArchive.encode(original, exportedAt: Date(timeIntervalSince1970: 5000))
        let decoded = try SnippetArchive.decode(data)
        XCTAssertEqual(decoded, original)
    }

    func test_decode_unsupportedVersion_throwsParseFailure() throws {
        let data = Data(#"{"version":99,"exportedAt":"1970-01-01T01:23:20Z","snippets":[]}"#.utf8)
        XCTAssertThrowsError(try SnippetArchive.decode(data)) { error in
            guard case ToolError.parseFailure(let reason, _) = error else {
                return XCTFail("expected parseFailure, got \(error)")
            }
            XCTAssertTrue(reason.contains("99"))
        }
    }

    func test_decode_malformedJSON_throwsParseFailure() throws {
        let data = Data("not json".utf8)
        XCTAssertThrowsError(try SnippetArchive.decode(data)) { error in
            guard case ToolError.parseFailure = error else {
                return XCTFail("expected parseFailure, got \(error)")
            }
        }
    }

    func test_decode_validVersionMalformedSnippets_throwsParseFailure() throws {
        let data = Data(#"{"version":1,"exportedAt":"1970-01-01T01:23:20Z","snippets":[{"nope":true}]}"#.utf8)
        XCTAssertThrowsError(try SnippetArchive.decode(data)) { error in
            guard case ToolError.parseFailure(let reason, _) = error else {
                return XCTFail("expected parseFailure, got \(error)")
            }
            XCTAssertTrue(reason.contains("Could not read"))
        }
    }
}
