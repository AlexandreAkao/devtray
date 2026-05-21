import XCTest
@testable import JSONToolKit

final class JSONEngineTests: XCTestCase {
    func test_format_validJSON_returnsPretty() throws {
        let input = "{\"a\":1,\"b\":2}"
        let result = JSONEngine.format(input)
        guard case .success(let pretty) = result else {
            XCTFail("expected success"); return
        }
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertTrue(pretty.contains("  \"a\""))
    }

    func test_format_sortsKeys() throws {
        let input = "{\"b\":1,\"a\":2}"
        let result = JSONEngine.format(input)
        guard case .success(let pretty) = result else {
            XCTFail(); return
        }
        let aIdx = pretty.firstRange(of: "\"a\"")!.lowerBound
        let bIdx = pretty.firstRange(of: "\"b\"")!.lowerBound
        XCTAssertLessThan(aIdx, bIdx)
    }

    func test_format_invalid_returnsParseFailure() {
        let result = JSONEngine.format("{not json}")
        if case .failure(.parseFailure) = result { return }
        XCTFail("expected parseFailure")
    }

    func test_format_empty_returnsInvalidInput() {
        let result = JSONEngine.format("   ")
        if case .failure(.invalidInput) = result { return }
        XCTFail("expected invalidInput")
    }

    func test_minify_validJSON_removesWhitespace() throws {
        let input = "{\n  \"a\": 1\n}"
        let result = JSONEngine.minify(input)
        guard case .success(let min) = result else { XCTFail(); return }
        XCTAssertEqual(min, "{\"a\":1}")
    }

    func test_validate_validJSON_returnsTrue() {
        XCTAssertTrue(JSONEngine.isValid("[1,2,3]"))
    }

    func test_validate_invalidJSON_returnsFalse() {
        XCTAssertFalse(JSONEngine.isValid("[1,2,"))
    }
}
