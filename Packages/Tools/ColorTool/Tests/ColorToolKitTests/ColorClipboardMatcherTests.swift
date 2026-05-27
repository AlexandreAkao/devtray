import XCTest
import DevTrayCore
@testable import ColorToolKit

final class ColorClipboardMatcherTests: XCTestCase {
    func test_hexMatchesStrong() {
        XCTAssertEqual(ColorClipboardMatcher.match("#FF8800")?.confidence, .strong)
    }
    func test_rgbMatchesStrong() {
        XCTAssertEqual(ColorClipboardMatcher.match("rgb(1, 2, 3)")?.confidence, .strong)
    }
    func test_plainTextDoesNotMatch() {
        XCTAssertNil(ColorClipboardMatcher.match("hello world"))
    }
    func test_emptyDoesNotMatch() {
        XCTAssertNil(ColorClipboardMatcher.match("   "))
    }
}
