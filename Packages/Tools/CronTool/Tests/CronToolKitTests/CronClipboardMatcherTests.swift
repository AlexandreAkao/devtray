import XCTest
import DevTrayCore
@testable import CronToolKit

final class CronClipboardMatcherTests: XCTestCase {
    func test_fiveValidFieldsMatchWeak() {
        XCTAssertEqual(CronClipboardMatcher.match("0 9 * * 1-5")?.confidence, .weak)
    }
    func test_macroDoesNotMatch() {
        XCTAssertNil(CronClipboardMatcher.match("@daily"))
    }
    func test_plainTextDoesNotMatch() {
        XCTAssertNil(CronClipboardMatcher.match("hello world"))
    }
    func test_sixFieldsDoNotMatch() {
        XCTAssertNil(CronClipboardMatcher.match("0 9 * * 1 5"))
    }
}
