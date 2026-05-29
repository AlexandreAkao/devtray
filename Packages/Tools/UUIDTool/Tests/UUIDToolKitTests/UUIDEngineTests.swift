import DevTrayCore
@testable import UUIDToolKit
import XCTest

final class UUIDEngineTests: XCTestCase {
    // MARK: - IDFormat

    func test_idFormat_displayNames() {
        XCTAssertEqual(IDFormat.uuidV4.displayName, "UUID v4")
        XCTAssertEqual(IDFormat.uuidV7.displayName, "UUID v7")
        XCTAssertEqual(IDFormat.ulid.displayName, "ULID")
    }

    // MARK: - Count validation

    func test_generate_countZero_returnsInvalidInput() {
        if case .failure(.invalidInput) = UUIDEngine.generate(format: .uuidV4, count: 0) { return }
        XCTFail("expected invalidInput")
    }

    func test_generate_countNegative_returnsInvalidInput() {
        if case .failure(.invalidInput) = UUIDEngine.generate(format: .uuidV4, count: -1) { return }
        XCTFail("expected invalidInput")
    }

    func test_generate_countAbove50_returnsInvalidInput() {
        if case .failure(.invalidInput) = UUIDEngine.generate(format: .uuidV4, count: 51) { return }
        XCTFail("expected invalidInput")
    }

    func test_generate_countOne_returnsSingleItem() {
        guard case .success(let ids) = UUIDEngine.generate(format: .uuidV4, count: 1) else {
            XCTFail(); return
        }
        XCTAssertEqual(ids.count, 1)
    }

    func test_generate_count50_returnsFiftyItems() {
        guard case .success(let ids) = UUIDEngine.generate(format: .uuidV4, count: 50) else {
            XCTFail(); return
        }
        XCTAssertEqual(ids.count, 50)
    }

    // MARK: - UUID v4

    func test_uuidV4_matchesV4Regex() {
        guard case .success(let ids) = UUIDEngine.generate(format: .uuidV4, count: 1),
              let id = ids.first else { XCTFail(); return }
        // 8-4-4-4-12, version nibble == 4, variant nibble in [89ab]
        let pattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"#
        XCTAssertNotNil(id.range(of: pattern, options: .regularExpression),
                        "v4 string \(id) does not match v4 pattern")
    }

    func test_uuidV4_batchOfTen_areUnique() {
        guard case .success(let ids) = UUIDEngine.generate(format: .uuidV4, count: 10) else {
            XCTFail(); return
        }
        XCTAssertEqual(Set(ids).count, 10)
    }

    // MARK: - UUID v7

    func test_uuidV7_versionNibbleIs7() {
        guard case .success(let ids) = UUIDEngine.generate(format: .uuidV7, count: 1),
              let id = ids.first else { XCTFail(); return }
        // Position 14 (0-indexed) is the version nibble in "xxxxxxxx-xxxx-Vxxx-..."
        // Layout: 8 hex + '-' + 4 hex + '-' + V hex => index 14 is V.
        let idx = id.index(id.startIndex, offsetBy: 14)
        XCTAssertEqual(id[idx], "7", "v7 id \(id) has wrong version nibble")
    }

    func test_uuidV7_variantBitsAre10() {
        guard case .success(let ids) = UUIDEngine.generate(format: .uuidV7, count: 1),
              let id = ids.first else { XCTFail(); return }
        // Position 19 is the variant nibble in "xxxxxxxx-xxxx-xxxx-Vxxx-..."
        let idx = id.index(id.startIndex, offsetBy: 19)
        let variantChar = id[idx]
        XCTAssertTrue("89ab".contains(variantChar),
                      "v7 id \(id) variant nibble \(variantChar) is not in [89ab]")
    }

    func test_uuidV7_timestampPrefix_isWithinOneSecondOfNow() {
        guard case .success(let ids) = UUIDEngine.generate(format: .uuidV7, count: 1),
              let id = ids.first else { XCTFail(); return }
        // First 12 hex chars = 48-bit big-endian unix-ms timestamp.
        // Format: "xxxxxxxx-xxxx-..." → take chars [0..8) + [9..13) = 12 hex.
        let hex = String(id.prefix(8)) + String(id.dropFirst(9).prefix(4))
        guard let ms = UInt64(hex, radix: 16) else { XCTFail(); return }
        let nowMs = UInt64(Date().timeIntervalSince1970 * 1000)
        XCTAssertLessThanOrEqual(abs(Int64(nowMs) - Int64(ms)), 1000,
                                 "v7 timestamp \(ms) is too far from now \(nowMs)")
    }

    func test_uuidV7_batch_areUnique() {
        guard case .success(let ids) = UUIDEngine.generate(format: .uuidV7, count: 20) else {
            XCTFail(); return
        }
        XCTAssertEqual(Set(ids).count, 20)
    }

    // MARK: - ULID

    func test_ulid_has26Chars() {
        guard case .success(let ids) = UUIDEngine.generate(format: .ulid, count: 1),
              let id = ids.first else { XCTFail(); return }
        XCTAssertEqual(id.count, 26)
    }

    func test_ulid_isUppercaseCrockford() {
        let alphabet = Set("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        guard case .success(let ids) = UUIDEngine.generate(format: .ulid, count: 5) else {
            XCTFail(); return
        }
        for id in ids {
            for ch in id {
                XCTAssertTrue(alphabet.contains(ch),
                              "ULID \(id) contains invalid char \(ch)")
            }
        }
    }

    func test_ulid_batchInSameMillisecond_sharesTimestampPrefix() {
        guard case .success(let ids) = UUIDEngine.generate(format: .ulid, count: 10) else {
            XCTFail(); return
        }
        // First 10 chars are the timestamp. Batch is generated tightly enough
        // that they should share a millisecond most of the time. Accept "all
        // prefixes within a small set" since a ms boundary mid-batch is possible.
        let prefixes = Set(ids.map { String($0.prefix(10)) })
        XCTAssertLessThanOrEqual(prefixes.count, 2,
                                 "ULID batch crossed too many ms boundaries: \(prefixes)")
    }

    func test_ulid_batch_areUnique() {
        guard case .success(let ids) = UUIDEngine.generate(format: .ulid, count: 50) else {
            XCTFail(); return
        }
        XCTAssertEqual(Set(ids).count, 50)
    }
}
