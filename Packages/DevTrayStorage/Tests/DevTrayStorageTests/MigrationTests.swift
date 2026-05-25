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

    func test_v2_createsSnippetsTableWithExpectedColumns() throws {
        let queue = try makeMigratedQueue()
        let columns: [Row] = try queue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(snippets)")
        }
        let names = columns.map { $0["name"] as String }
        XCTAssertEqual(names, [
            "id", "title", "content", "language", "tags",
            "is_favorite", "created_at", "updated_at", "use_count", "last_used_at"
        ])
    }

    func test_v2_createsIndexes() throws {
        let queue = try makeMigratedQueue()
        let indexNames: [String] = try queue.read { db in
            try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'index' AND tbl_name = 'snippets'
            """)
        }
        XCTAssertTrue(indexNames.contains("idx_snippets_updated"))
        XCTAssertTrue(indexNames.contains("idx_snippets_favorite"))
    }

    func test_v2_createsFTSTable() throws {
        let queue = try makeMigratedQueue()
        let names: [String] = try queue.read { db in
            try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'table' AND name = 'snippets_fts'
            """)
        }
        XCTAssertEqual(names, ["snippets_fts"])
    }

    func test_v1ToV2_preservesToolUsageData() throws {
        let queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(on: &migrator)

        // Migrate to v1 only, then seed tool_usage.
        try migrator.migrate(queue, upTo: "v1_tool_usage")
        try queue.write { db in
            try db.execute(sql: "INSERT INTO tool_usage (tool_id, used_at) VALUES (?, ?)",
                           arguments: ["json", 123.0])
            try db.execute(sql: "INSERT INTO tool_usage (tool_id, used_at) VALUES (?, ?)",
                           arguments: ["jwt", 456.0])
        }

        // Apply v2.
        try migrator.migrate(queue)

        // tool_usage rows survive untouched.
        let usageCount = try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM tool_usage") ?? -1
        }
        XCTAssertEqual(usageCount, 2)

        // A post-migration snippet round-trips and is FTS-searchable.
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO snippets (id, title, content, language, tags,
                    is_favorite, created_at, updated_at, use_count, last_used_at)
                VALUES ('s1', 'Greeting', 'hello there', NULL, '[]', 0, 1.0, 1.0, 0, NULL)
            """)
        }
        let found = try queue.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM snippets
                JOIN snippets_fts ON snippets_fts.rowid = snippets.rowid
                WHERE snippets_fts MATCH 'hello'
            """) ?? -1
        }
        XCTAssertEqual(found, 1)
    }
}
