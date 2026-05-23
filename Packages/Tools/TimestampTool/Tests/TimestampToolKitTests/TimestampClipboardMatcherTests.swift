import XCTest
@testable import TimestampToolKit
import DevTrayCore

final class TimestampClipboardMatcherTests: XCTestCase {
    func test_unixSeconds_returnsWeak() {
        XCTAssertEqual(
            TimestampClipboardMatcher.match("1704067200")?.confidence,
            .weak
        )
    }

    func test_unixMillis_returnsWeak() {
        XCTAssertEqual(
            TimestampClipboardMatcher.match("1704067200000")?.confidence,
            .weak
        )
    }

    func test_yearOutOfRange_returnsNil() {
        XCTAssertNil(TimestampClipboardMatcher.match("9999999999"))
    }

    func test_nonNumeric_returnsNil() {
        XCTAssertNil(TimestampClipboardMatcher.match("hello"))
    }

    func test_wrongDigitCount_returnsNil() {
        XCTAssertNil(TimestampClipboardMatcher.match("123"))
    }

    func test_emptyString_returnsNil() {
        XCTAssertNil(TimestampClipboardMatcher.match(""))
    }
}
