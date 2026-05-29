import DevTrayCore
@testable import JWTToolKit
import XCTest

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

    func test_jwtWithEmptySegments_returnsNil() {
        XCTAssertNil(JWTClipboardMatcher.match("eyJ.."))
        XCTAssertNil(JWTClipboardMatcher.match("eyJabc.."))
        XCTAssertNil(JWTClipboardMatcher.match("eyJ.x."))
    }
}
