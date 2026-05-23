import XCTest
@testable import HashToolKit
import DevTrayCore

final class HashClipboardMatcherTests: XCTestCase {
    func test_md5Hex_returnsWeak() {
        XCTAssertEqual(
            HashClipboardMatcher.match("d41d8cd98f00b204e9800998ecf8427e")?.confidence,
            .weak
        )
    }

    func test_sha256Hex_returnsWeak() {
        let sha = String(repeating: "a", count: 64)
        XCTAssertEqual(
            HashClipboardMatcher.match(sha)?.confidence,
            .weak
        )
    }

    func test_arbitraryLengthHex_returnsNil() {
        let s = String(repeating: "a", count: 50)
        XCTAssertNil(HashClipboardMatcher.match(s))
    }

    func test_nonHexLength32_returnsNil() {
        let s = String(repeating: "z", count: 32)
        XCTAssertNil(HashClipboardMatcher.match(s))
    }

    func test_emptyString_returnsNil() {
        XCTAssertNil(HashClipboardMatcher.match(""))
    }
}
