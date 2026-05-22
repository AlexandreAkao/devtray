import XCTest
@testable import DevTrayStorage
import GRDB

final class DatabaseOpenerTests: XCTestCase {
    private var sandbox: URL!

    override func setUpWithError() throws {
        sandbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevTrayStorageTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
    }

    func test_open_createsParentDirectory_andOpensQueue() throws {
        let url = sandbox.appendingPathComponent("devtray.sqlite")
        let queue = try DatabaseOpener.open(at: url)
        try queue.write { db in
            try db.execute(sql: "CREATE TABLE smoke (id INTEGER)")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_open_existingValidDatabase_succeeds() throws {
        let url = sandbox.appendingPathComponent("devtray.sqlite")
        _ = try DatabaseOpener.open(at: url) // first open creates file
        let reopened = try DatabaseOpener.open(at: url)
        try reopened.read { _ in /* no-op */ }
    }

    func test_open_corruptFile_isRenamedAndFreshDatabaseCreated() throws {
        let url = sandbox.appendingPathComponent("devtray.sqlite")
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        // Write garbage that SQLite cannot open.
        try Data(repeating: 0xFF, count: 4096).write(to: url)

        let queue = try DatabaseOpener.open(at: url)
        try queue.read { _ in /* must not throw */ }

        // The corrupt file should have been renamed alongside the new one.
        let entries = try FileManager.default.contentsOfDirectory(atPath: sandbox.path)
        let renamed = entries.filter { $0.hasPrefix("devtray.sqlite.corrupted-") }
        XCTAssertEqual(renamed.count, 1, "expected exactly one renamed corrupt file; got \(entries)")
    }
}
