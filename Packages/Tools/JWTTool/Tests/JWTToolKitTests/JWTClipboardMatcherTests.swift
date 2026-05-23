import XCTest
@testable import JWTToolKit
import DevTrayCore

final class JWTClipboardMatcherTests: XCTestCase {
    func test_validJWT_returnsStrong() {
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature"
        XCTAssertEqual(
            JWTClipboardMatcher.match(jwt)?.confidence,
            .strong
        )
    }

    func test_jwtWithLeadingWhitespace_returnsStrong() {
        let jwt = "   eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.x  "
        XCTAssertEqual(
            JWTClipboardMatcher.match(jwt)?.confidence,
            .strong
        )
    }

    func test_randomText_returnsNil() {
        XCTAssertNil(JWTClipboardMatcher.match("hello world"))
    }

    func test_twoSegmentsOnly_returnsNil() {
        XCTAssertNil(JWTClipboardMatcher.match("eyJhbGci.eyJzdWI"))
    }

    func test_emptyString_returnsNil() {
        XCTAssertNil(JWTClipboardMatcher.match(""))
    }
}
