import XCTest
@testable import Base64ToolKit

final class Base64EngineTests: XCTestCase {
    func test_encode_asciiText_returnsBase64() {
        let result = Base64Engine.encode("hello")
        guard case .success(let s) = result else { XCTFail(); return }
        XCTAssertEqual(s, "aGVsbG8=")
    }

    func test_encode_unicodeText_works() {
        let result = Base64Engine.encode("héllo 🌍")
        guard case .success(let s) = result else { XCTFail(); return }
        XCTAssertEqual(s, "aMOpbGxvIPCfjI0=")
    }

    func test_encode_empty_returnsInvalidInput() {
        let result = Base64Engine.encode("")
        if case .failure(.invalidInput) = result { return }
        XCTFail("expected invalidInput")
    }

    func test_decode_validBase64_returnsText() {
        let result = Base64Engine.decode("aGVsbG8=")
        guard case .success(let s) = result else { XCTFail(); return }
        XCTAssertEqual(s, "hello")
    }

    func test_decode_paddedAndUnpadded_bothWork() {
        XCTAssertEqual(try? Base64Engine.decode("aGVsbG8=").get(), "hello")
        XCTAssertEqual(try? Base64Engine.decode("aGVsbG8").get(), "hello")
    }

    func test_decode_invalidBase64_returnsParseFailure() {
        let result = Base64Engine.decode("not~base64!!")
        if case .failure(.parseFailure) = result { return }
        XCTFail("expected parseFailure")
    }

    func test_decode_nonUTF8Bytes_returnsParseFailure() {
        let result = Base64Engine.decode("//4=")
        if case .failure(.parseFailure) = result { return }
        XCTFail("expected parseFailure for non-UTF8")
    }
}
