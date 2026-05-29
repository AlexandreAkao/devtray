@testable import DevTrayStorage
import GRDB
import XCTest

final class PackageSmokeTest: XCTestCase {
    func test_grdb_canOpenInMemoryQueue() throws {
        let queue = try DatabaseQueue()
        try queue.write { db in
            try db.execute(sql: "CREATE TABLE smoke (id INTEGER)")
        }
        let count = try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM smoke") ?? -1
        }
        XCTAssertEqual(count, 0)
    }
}
