import XCTest
import DevTrayCore

final class InMemoryUsageStoreTests: XCTestCase {
    func test_record_thenTopTools_returnsOneRank() async throws {
        let store = InMemoryUsageStore()
        let now = Date()
        await store.record(toolID: ToolID(rawValue: "jwt"), at: now)
        let ranks = try await store.topTools(window: .allTime, limit: 3, now: now)
        XCTAssertEqual(ranks, [ToolUsageRank(toolID: ToolID(rawValue: "jwt"), count: 1)])
    }

    func test_topTools_multipleTools_ranksByCountDesc() async throws {
        let store = InMemoryUsageStore()
        let now = Date()
        for _ in 0..<5 { await store.record(toolID: "jwt", at: now) }
        for _ in 0..<3 { await store.record(toolID: "json", at: now) }
        for _ in 0..<7 { await store.record(toolID: "hash", at: now) }

        let ranks = try await store.topTools(window: .allTime, limit: 3, now: now)
        XCTAssertEqual(ranks.map(\.toolID.rawValue), ["hash", "jwt", "json"])
        XCTAssertEqual(ranks.map(\.count), [7, 5, 3])
    }

    func test_topTools_windowExcludesOlderRows() async throws {
        let store = InMemoryUsageStore()
        let now = Date()
        let old = now.addingTimeInterval(-31 * 86_400) // 31 days ago

        await store.record(toolID: "jwt", at: old)
        await store.record(toolID: "json", at: now)

        // limit: 1 keeps the all-time fallback out of scope so this test
        // only verifies the window filter (jwt is outside, json is inside).
        let ranks = try await store.topTools(window: .lastDays(30), limit: 1, now: now)
        XCTAssertEqual(ranks.map(\.toolID.rawValue), ["json"])
    }

    func test_topTools_windowFallback_fillsFromAllTime() async throws {
        let store = InMemoryUsageStore()
        let now = Date()
        let old = now.addingTimeInterval(-100 * 86_400)

        await store.record(toolID: "jwt", at: now)
        await store.record(toolID: "json", at: old)
        await store.record(toolID: "hash", at: old)

        let ranks = try await store.topTools(window: .lastDays(30), limit: 3, now: now)
        XCTAssertEqual(Set(ranks.map(\.toolID.rawValue)), ["jwt", "json", "hash"])
        // jwt is from the window (count 1); json+hash are appended from all-time.
        XCTAssertEqual(ranks.first?.toolID.rawValue, "jwt")
    }

    func test_topTools_emptyStore_returnsEmpty() async throws {
        let store = InMemoryUsageStore()
        let ranks = try await store.topTools(window: .lastDays(30), limit: 3, now: Date())
        XCTAssertEqual(ranks, [])
    }
}
