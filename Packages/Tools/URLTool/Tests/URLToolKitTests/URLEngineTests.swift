import DevTrayCore
@testable import URLToolKit
import XCTest

final class URLEngineTests: XCTestCase {
    // Encode

    func test_encode_spaces_becomePercent20() {
        let result = URLEngine.encode("hello world")
        guard case .success(let s) = result else { XCTFail("expected success"); return }
        XCTAssertEqual(s, "hello%20world")
    }

    func test_encode_unicode_isPercentEncoded() {
        let result = URLEngine.encode("café")
        guard case .success(let s) = result else { XCTFail("expected success"); return }
        XCTAssertEqual(s, "caf%C3%A9")
    }

    func test_encode_emoji_isPercentEncoded() {
        let result = URLEngine.encode("a🌍b")
        guard case .success(let s) = result else { XCTFail("expected success"); return }
        XCTAssertEqual(s, "a%F0%9F%8C%8Db")
    }

    func test_encode_empty_returnsInvalidInput() {
        let result = URLEngine.encode("")
        if case .failure(.invalidInput) = result { return }
        XCTFail("expected invalidInput")
    }

    func test_encode_whitespaceOnly_returnsInvalidInput() {
        let result = URLEngine.encode("   \n\t")
        if case .failure(.invalidInput) = result { return }
        XCTFail("expected invalidInput")
    }

    // Decode

    func test_decode_percentSpaces_becomeSpaces() {
        let result = URLEngine.decode("hello%20world")
        guard case .success(let s) = result else { XCTFail("expected success"); return }
        XCTAssertEqual(s, "hello world")
    }

    func test_decode_percentUnicode_returnsUnicode() {
        let result = URLEngine.decode("caf%C3%A9")
        guard case .success(let s) = result else { XCTFail("expected success"); return }
        XCTAssertEqual(s, "café")
    }

    func test_decode_invalidPercent_returnsParseFailure() {
        let result = URLEngine.decode("%ZZ")
        if case .failure(.parseFailure) = result { return }
        XCTFail("expected parseFailure")
    }

    func test_decode_truncatedPercent_returnsParseFailure() {
        let result = URLEngine.decode("hello%2")
        if case .failure(.parseFailure) = result { return }
        XCTFail("expected parseFailure")
    }

    func test_decode_empty_returnsInvalidInput() {
        let result = URLEngine.decode("")
        if case .failure(.invalidInput) = result { return }
        XCTFail("expected invalidInput")
    }

    // Round-trip

    func test_encodeDecode_roundTrip_preservesString() {
        let original = "https://example.com/path?q=hello world&n=café"
        guard case .success(let encoded) = URLEngine.encode(original),
              case .success(let decoded) = URLEngine.decode(encoded) else {
            XCTFail("round-trip should succeed"); return
        }
        XCTAssertEqual(decoded, original)
    }
}
