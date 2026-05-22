import XCTest
@testable import DevTrayStorage
import GRDB

final class MigrationTests: XCTestCase {
    private func makeMigratedQueue() throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(on: &migrator)
        try migrator.migrate(queue)
        return queue
    }

    func test_v1_createsToolUsageTable() throws {
        let queue = try makeMigratedQueue()
        let columns: [Row] = try queue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(tool_usage)")
        }
        let names = columns.map { $0["name"] as String }
        let types = columns.map { $0["type"] as String }
        XCTAssertEqual(names, ["tool_id", "used_at"])
        XCTAssertEqual(types, ["TEXT", "REAL"])
    }

    func test_v1_createsCompositeIndex() throws {
        let queue = try makeMigratedQueue()
        let indexNames: [String] = try queue.read { db in
            try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'index' AND tbl_name = 'tool_usage'
            """)
        }
        XCTAssertTrue(indexNames.contains("idx_tool_usage_tool_used"),
                      "expected idx_tool_usage_tool_used; got \(indexNames)")
    }

    func test_migrator_isIdempotent() throws {
        let queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(on: &migrator)
        try migrator.migrate(queue)
        XCTAssertNoThrow(try migrator.migrate(queue))
    }
}
