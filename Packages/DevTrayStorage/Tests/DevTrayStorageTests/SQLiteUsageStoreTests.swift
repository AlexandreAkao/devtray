import XCTest
@testable import DevTrayStorage
import DevTrayCore
import GRDB

final class SQLiteUsageStoreTests: XCTestCase {
    private func makeStore() throws -> SQLiteUsageStore {
        let queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(on: &migrator)
        try migrator.migrate(queue)
        return SQLiteUsageStore(dbQueue: queue)
    }

    func test_record_insertsRowWithRightValues() async throws {
        let store = try makeStore()
        let now = Date()
        await store.record(toolID: "jwt", at: now)

        let rows = try await store.debugDumpAllRows()
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.toolID.rawValue, "jwt")
        XCTAssertEqual(row.usedAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_record_sameToolMultipleTimes_appendsAllRows() async throws {
        let store = try makeStore()
        let now = Date()
        for _ in 0..<5 { await store.record(toolID: "jwt", at: now) }
        let rows = try await store.debugDumpAllRows()
        XCTAssertEqual(rows.count, 5)
    }

    func test_topTools_emptyDatabase_returnsEmpty() async throws {
        let store = try makeStore()
        let ranks = try await store.topTools(window: .lastDays(30), limit: 3, now: Date())
        XCTAssertEqual(ranks, [])
    }

    func test_topTools_singleTool_returnsOneRank() async throws {
        let store = try makeStore()
        let now = Date()
        for _ in 0..<3 { await store.record(toolID: "jwt", at: now) }
        let ranks = try await store.topTools(window: .allTime, limit: 3, now: now)
        XCTAssertEqual(ranks, [ToolUsageRank(toolID: "jwt", count: 3)])
    }

    func test_topTools_multipleTools_ranksByCountDesc() async throws {
        let store = try makeStore()
        let now = Date()
        for _ in 0..<5 { await store.record(toolID: "jwt", at: now) }
        for _ in 0..<3 { await store.record(toolID: "json", at: now) }
        for _ in 0..<7 { await store.record(toolID: "hash", at: now) }

        let ranks = try await store.topTools(window: .allTime, limit: 3, now: now)
        XCTAssertEqual(ranks.map(\.toolID.rawValue), ["hash", "jwt", "json"])
        XCTAssertEqual(ranks.map(\.count), [7, 5, 3])
    }

    func test_topTools_respectsLimit() async throws {
        let store = try makeStore()
        let now = Date()
        for id in ["a", "b", "c", "d", "e"] {
            await store.record(toolID: ToolID(rawValue: id), at: now)
        }
        let ranks = try await store.topTools(window: .allTime, limit: 3, now: now)
        XCTAssertEqual(ranks.count, 3)
    }

    func test_topTools_windowExcludesOlderRows() async throws {
        let store = try makeStore()
        let now = Date()
        let old = now.addingTimeInterval(-31 * 86_400)
        await store.record(toolID: "jwt", at: old)
        await store.record(toolID: "json", at: now)

        // limit: 1 keeps the all-time fallback out of scope so this test
        // only verifies the window filter (jwt is outside, json is inside).
        let ranks = try await store.topTools(window: .lastDays(30), limit: 1, now: now)
        XCTAssertEqual(ranks.map(\.toolID.rawValue), ["json"])
    }

    func test_topTools_windowFallback_fillsFromAllTime() async throws {
        let store = try makeStore()
        let now = Date()
        let old = now.addingTimeInterval(-100 * 86_400)

        await store.record(toolID: "jwt", at: now)
        await store.record(toolID: "json", at: old)
        await store.record(toolID: "hash", at: old)

        let ranks = try await store.topTools(window: .lastDays(30), limit: 3, now: now)
        XCTAssertEqual(ranks.count, 3)
        XCTAssertEqual(ranks.first?.toolID.rawValue, "jwt", "in-window result comes first")
        XCTAssertEqual(Set(ranks.map(\.toolID.rawValue)), ["jwt", "json", "hash"])
        // Each tool was recorded once; fallback must preserve all-time counts, not zero them out.
        XCTAssertTrue(ranks.allSatisfy { $0.count == 1 }, "fallback ranks must carry their all-time counts; got \(ranks)")
    }

    func test_topTools_windowFallback_doesNotDuplicate() async throws {
        let store = try makeStore()
        let now = Date()
        let old = now.addingTimeInterval(-100 * 86_400)
        for _ in 0..<3 { await store.record(toolID: "jwt", at: now) }   // in-window
        for _ in 0..<5 { await store.record(toolID: "jwt", at: old) }   // all-time

        let ranks = try await store.topTools(window: .lastDays(30), limit: 3, now: now)
        XCTAssertEqual(ranks.count, 1)
        XCTAssertEqual(ranks.first?.toolID.rawValue, "jwt")
        XCTAssertEqual(ranks.first?.count, 3, "fallback must NOT re-add jwt from all-time")
    }

    func test_record_concurrentWrites_doNotCrash() async throws {
        let store = try makeStore()
        let now = Date()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask { await store.record(toolID: "jwt", at: now) }
            }
        }
        let rows = try await store.debugDumpAllRows()
        XCTAssertEqual(rows.count, 100)
    }
}
