import XCTest
import SwiftUI
@testable import DevTrayCore

@MainActor
final class SpotlightRankerTests: XCTestCase {

    // MARK: - Test fixtures

    private enum FixtureKind { case jwtLike, urlLike, plain }

    private enum FixtureToolJWT: Tool {
        static let id: ToolID = "jwt"
        static let displayName = "JWT"
        static let iconName = "key.horizontal"
        static let keywords = ["token", "json web token"]
        static let category: ToolCategory = .encoding
        @MainActor static func makeView() -> AnyView { AnyView(EmptyView()) }
        static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
            clipboard.hasPrefix("eyJ") ? ClipboardMatchScore(.strong) : nil
        }
    }

    private enum FixtureToolURL: Tool {
        static let id: ToolID = "url"
        static let displayName = "URL"
        static let iconName = "link"
        static let keywords = ["link"]
        static let category: ToolCategory = .encoding
        @MainActor static func makeView() -> AnyView { AnyView(EmptyView()) }
        static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
            clipboard.contains("://") ? ClipboardMatchScore(.strong) : nil
        }
    }

    private enum FixtureToolJSON: Tool {
        static let id: ToolID = "json"
        static let displayName = "JSON"
        static let iconName = "curlybraces"
        static let keywords = ["format"]
        static let category: ToolCategory = .formatting
        @MainActor static func makeView() -> AnyView { AnyView(EmptyView()) }
    }

    private enum FixtureToolHash: Tool {
        static let id: ToolID = "hash"
        static let displayName = "Hash"
        static let iconName = "number"
        static let keywords = ["md5", "sha"]
        static let category: ToolCategory = .crypto
        @MainActor static func makeView() -> AnyView { AnyView(EmptyView()) }
        static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
            if clipboard.count == 32 || clipboard.hasPrefix("eyJ") {
                return ClipboardMatchScore(.weak)
            }
            return nil
        }
    }

    private func makeRegistry() -> ToolRegistry {
        let r = ToolRegistry()
        r.register(FixtureToolJWT.self)
        r.register(FixtureToolURL.self)
        r.register(FixtureToolJSON.self)
        r.register(FixtureToolHash.self)
        return r
    }

    // MARK: - Empty query

    func test_emptyQuery_emptyClipboard_returnsTopToolsOnly() async {
        let usage = InMemoryUsageStore()
        await usage.record(toolID: "json", at: .now)
        await usage.record(toolID: "json", at: .now)
        await usage.record(toolID: "url", at: .now)
        let ranker = SpotlightRanker(registry: makeRegistry(), usage: usage)
        let results = await ranker.rank(query: "", clipboard: nil, limit: 8)
        XCTAssertEqual(results.first?.toolID, "json")
        XCTAssertFalse(results.allSatisfy { $0.fromClipboard })
        XCTAssertFalse(results.contains(where: { $0.fromClipboard }))
    }

    func test_emptyQuery_strongClipboardMatch_putsMatchOnTopWithPill() async {
        let usage = InMemoryUsageStore()
        await usage.record(toolID: "json", at: .now)
        await usage.record(toolID: "json", at: .now)
        let ranker = SpotlightRanker(registry: makeRegistry(), usage: usage)
        let results = await ranker.rank(query: "", clipboard: "eyJhbGc.x.y", limit: 8)
        XCTAssertEqual(results.first?.toolID, "jwt")
        XCTAssertTrue(results.first?.fromClipboard ?? false)
        XCTAssertEqual(results.dropFirst().filter { $0.fromClipboard }.count, 0)
    }

    func test_emptyQuery_strongBeatsWeak() async {
        let usage = InMemoryUsageStore()
        let ranker = SpotlightRanker(registry: makeRegistry(), usage: usage)
        // Clipboard "eyJhbGc.x.y" fires JWT (.strong) AND Hash (.weak, opted into
        // matching the JWT prefix above to set up this head-to-head). Top must be
        // JWT because confidence > usage rank in pickTopMatcher.
        let results = await ranker.rank(query: "", clipboard: "eyJhbGc.x.y", limit: 8)
        XCTAssertEqual(results.first?.toolID, "jwt")
        XCTAssertTrue(results.first?.fromClipboard ?? false)
    }

    func test_emptyQuery_weakOnlyMatch_putsWeakOnTop() async {
        let usage = InMemoryUsageStore()
        let ranker = SpotlightRanker(registry: makeRegistry(), usage: usage)
        let thirtyTwo = String(repeating: "a", count: 32)
        let results = await ranker.rank(query: "", clipboard: thirtyTwo, limit: 8)
        XCTAssertEqual(results.first?.toolID, "hash")
        XCTAssertTrue(results.first?.fromClipboard ?? false)
    }

    // MARK: - With query

    func test_query_filtersByFuzzyMatch() async {
        let usage = InMemoryUsageStore()
        let ranker = SpotlightRanker(registry: makeRegistry(), usage: usage)
        let results = await ranker.rank(query: "jso", clipboard: nil, limit: 8)
        XCTAssertEqual(results.first?.toolID, "json")
    }

    func test_query_clipboardMatchOnFilteredOutTool_noBadge() async {
        let usage = InMemoryUsageStore()
        let ranker = SpotlightRanker(registry: makeRegistry(), usage: usage)
        // "j" matches JWT and JSON via subsequence; clipboard is a URL that
        // only the URL tool's matcher would recognize — but URL is not in the
        // fuzzy-filtered rows, so no badge appears anywhere in the result.
        let results = await ranker.rank(query: "j", clipboard: "https://x.example", limit: 8)
        XCTAssertFalse(results.contains(where: { $0.fromClipboard }))
    }

    func test_query_withClipboardThatMatchesAMatchingRow_setsBadgeOnIt() async {
        let usage = InMemoryUsageStore()
        let ranker = SpotlightRanker(registry: makeRegistry(), usage: usage)
        let results = await ranker.rank(query: "jw", clipboard: "eyJhbGc.x.y", limit: 8)
        XCTAssertEqual(results.first?.toolID, "jwt")
        XCTAssertTrue(results.first?.fromClipboard ?? false)
    }

    func test_query_noMatches_returnsEmpty() async {
        let usage = InMemoryUsageStore()
        let ranker = SpotlightRanker(registry: makeRegistry(), usage: usage)
        let results = await ranker.rank(query: "zzz", clipboard: nil, limit: 8)
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Limits and tie-breaks

    func test_limit_isHonored() async {
        let usage = InMemoryUsageStore()
        let ranker = SpotlightRanker(registry: makeRegistry(), usage: usage)
        let results = await ranker.rank(query: "", clipboard: nil, limit: 2)
        XCTAssertLessThanOrEqual(results.count, 2)
    }

    func test_emptyQuery_excludesTopFromRest() async {
        let usage = InMemoryUsageStore()
        await usage.record(toolID: "jwt", at: .now)
        await usage.record(toolID: "json", at: .now)
        let ranker = SpotlightRanker(registry: makeRegistry(), usage: usage)
        let results = await ranker.rank(query: "", clipboard: "eyJhbGc.x.y", limit: 8)
        let topID = results.first!.toolID
        XCTAssertEqual(topID, "jwt")
        XCTAssertEqual(results.dropFirst().filter { $0.toolID == topID }.count, 0)
    }
}
