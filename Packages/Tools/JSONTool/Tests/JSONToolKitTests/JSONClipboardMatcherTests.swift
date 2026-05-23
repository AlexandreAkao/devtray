import XCTest
@testable import JSONToolKit
import DevTrayCore

final class JSONClipboardMatcherTests: XCTestCase {
    func test_objectShape_returnsStrong() {
        XCTAssertEqual(
            JSONClipboardMatcher.match("{\"a\":1}")?.confidence,
            .strong
        )
    }

    func test_arrayShape_returnsStrong() {
        XCTAssertEqual(
            JSONClipboardMatcher.match("[1, 2, 3]")?.confidence,
            .strong
        )
    }

    func test_withWhitespacePadding_returnsStrong() {
        XCTAssertEqual(
            JSONClipboardMatcher.match("  \n  { \"x\": true } \n ")?.confidence,
            .strong
        )
    }

    func test_objectOpenOnly_returnsNil() {
        XCTAssertNil(JSONClipboardMatcher.match("{\"a\":1"))
    }

    func test_plainText_returnsNil() {
        XCTAssertNil(JSONClipboardMatcher.match("hello"))
    }

    func test_emptyString_returnsNil() {
        XCTAssertNil(JSONClipboardMatcher.match(""))
    }
}
