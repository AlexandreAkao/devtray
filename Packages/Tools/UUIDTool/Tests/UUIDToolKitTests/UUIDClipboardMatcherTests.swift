import XCTest
@testable import UUIDToolKit
import DevTrayCore

final class UUIDClipboardMatcherTests: XCTestCase {
    func test_uuidLower_returnsStrong() {
        XCTAssertEqual(
            UUIDClipboardMatcher.match("550e8400-e29b-41d4-a716-446655440000")?.confidence,
            .strong
        )
    }

    func test_uuidUpper_returnsStrong() {
        XCTAssertEqual(
            UUIDClipboardMatcher.match("550E8400-E29B-41D4-A716-446655440000")?.confidence,
            .strong
        )
    }

    func test_ulid_returnsStrong() {
        XCTAssertEqual(
            UUIDClipboardMatcher.match("01ARZ3NDEKTSV4RRFFQ69G5FAV")?.confidence,
            .strong
        )
    }

    func test_uuidMissingDash_returnsNil() {
        XCTAssertNil(UUIDClipboardMatcher.match("550e8400e29b41d4a716446655440000"))
    }

    func test_emptyString_returnsNil() {
        XCTAssertNil(UUIDClipboardMatcher.match(""))
    }
}
