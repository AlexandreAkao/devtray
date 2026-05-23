import XCTest
@testable import Base64ToolKit
import DevTrayCore

final class Base64ClipboardMatcherTests: XCTestCase {
    func test_validBase64NoPadding_returnsWeak() {
        XCTAssertEqual(
            Base64ClipboardMatcher.match("aGVsbG93b3JsZA==")?.confidence,
            .weak
        )
    }

    func test_validBase64_returnsWeak() {
        XCTAssertEqual(
            Base64ClipboardMatcher.match("U3dpZnQ=")?.confidence,
            .weak
        )
    }

    func test_containsDot_returnsNil() {
        XCTAssertNil(Base64ClipboardMatcher.match("eyJhbGc.eyJzdWI.sig"))
    }

    func test_invalidLength_returnsNil() {
        XCTAssertNil(Base64ClipboardMatcher.match("abcdefg"))
    }

    func test_invalidAlphabet_returnsNil() {
        XCTAssertNil(Base64ClipboardMatcher.match("not!base64@@"))
    }

    func test_shortString_returnsNil() {
        XCTAssertNil(Base64ClipboardMatcher.match("U3df"))
    }

    func test_emptyString_returnsNil() {
        XCTAssertNil(Base64ClipboardMatcher.match(""))
    }
}
