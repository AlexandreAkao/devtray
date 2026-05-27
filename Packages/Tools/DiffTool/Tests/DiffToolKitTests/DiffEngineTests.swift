import XCTest
@testable import DiffToolKit

final class DiffEngineTests: XCTestCase {
    func test_identical_allEqual() {
        let rows = DiffEngine.diffLines("a\nb", "a\nb")
        XCTAssertEqual(rows.map(\.kind), [.equal, .equal])
        XCTAssertTrue(DiffEngine.unifiedHunks("a\nb", "a\nb").isEmpty)
    }

    func test_pureInsert() {
        let rows = DiffEngine.diffLines("x", "x\ny")
        XCTAssertEqual(rows.map(\.kind), [.equal, .insert])
        XCTAssertEqual(rows[1].text, "y")
        XCTAssertEqual(rows[1].rightLine, 2)
        XCTAssertNil(rows[1].leftLine)
    }

    func test_pureDelete() {
        let rows = DiffEngine.diffLines("x\ny", "x")
        XCTAssertEqual(rows.map(\.kind), [.equal, .delete])
        XCTAssertEqual(rows[1].text, "y")
        XCTAssertEqual(rows[1].leftLine, 2)
        XCTAssertNil(rows[1].rightLine)
    }

    func test_replaceLine() {
        let rows = DiffEngine.diffLines("x\ny\nz", "x\nY\nz")
        XCTAssertEqual(rows.map(\.kind), [.equal, .delete, .insert, .equal])
        XCTAssertEqual(rows[1].text, "y")
        XCTAssertEqual(rows[2].text, "Y")
    }

    func test_unifiedHunks_haveHeaderAndRows() {
        let a = "1\n2\n3\n4\n5\n6\n7\n8\n9\n10"
        let b = "1\n2\n3\n4\nX\n6\n7\n8\n9\n10"
        let hunks = DiffEngine.unifiedHunks(a, b, context: 1)
        XCTAssertEqual(hunks.count, 1)
        XCTAssertTrue(hunks[0].header.hasPrefix("@@"))
        XCTAssertEqual(hunks[0].rows.map(\.kind), [.equal, .delete, .insert, .equal])
    }

    func test_unifiedHunks_separateChangesProduceTwoHunks() {
        let a = "1\n2\n3\n4\n5\n6\n7"
        let b = "X\n2\n3\n4\n5\n6\nY"
        XCTAssertEqual(DiffEngine.unifiedHunks(a, b, context: 1).count, 2)
    }

    func test_unifiedHunks_nearbyChangesMergeIntoOneHunk() {
        let a = "1\n2\n3\n4\n5"
        let b = "X\n2\n3\n4\nY"
        XCTAssertEqual(DiffEngine.unifiedHunks(a, b).count, 1)   // default context 3 merges
    }
}
