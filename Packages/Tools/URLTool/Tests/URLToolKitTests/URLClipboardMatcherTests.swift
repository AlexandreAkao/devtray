import XCTest
@testable import URLToolKit
import DevTrayCore

final class URLClipboardMatcherTests: XCTestCase {
    func test_https_returnsStrong() {
        XCTAssertEqual(
            URLClipboardMatcher.match("https://example.com/path?q=1")?.confidence,
            .strong
        )
    }

    func test_http_returnsStrong() {
        XCTAssertEqual(
            URLClipboardMatcher.match("http://localhost:3000")?.confidence,
            .strong
        )
    }

    func test_ftp_returnsStrong() {
        XCTAssertEqual(
            URLClipboardMatcher.match("ftp://files.example.com/file.zip")?.confidence,
            .strong
        )
    }

    func test_plainText_returnsNil() {
        XCTAssertNil(URLClipboardMatcher.match("hello world"))
    }

    func test_schemeOnly_returnsNil() {
        XCTAssertNil(URLClipboardMatcher.match("https://"))
    }
}
