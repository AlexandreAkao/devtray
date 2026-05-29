import DevTrayCore
import XCTest

final class ToolErrorTests: XCTestCase {
    func test_parseFailure_hasLocalizedDescription() {
        let err: ToolError = .parseFailure(reason: "bad JSON", hint: nil)
        XCTAssertEqual(err.errorDescription, "bad JSON")
    }

    func test_parseFailure_withHint_includesHintInDescription() {
        let err: ToolError = .parseFailure(reason: "bad JSON", hint: "check line 4")
        XCTAssertEqual(err.errorDescription, "bad JSON (check line 4)")
    }

    func test_invalidInput_hasLocalizedDescription() {
        let err: ToolError = .invalidInput(reason: "empty")
        XCTAssertEqual(err.errorDescription, "empty")
    }

    func test_equatable_sameCase_sameValue_isEqual() {
        let a: ToolError = .parseFailure(reason: "x", hint: nil)
        let b: ToolError = .parseFailure(reason: "x", hint: nil)
        XCTAssertEqual(a, b)
    }

    func test_parseFailure_withEmptyHint_omitsHint() {
        let err: ToolError = .parseFailure(reason: "bad JSON", hint: "")
        XCTAssertEqual(err.errorDescription, "bad JSON")
    }

    func test_unsupportedOperation_hasLocalizedDescription() {
        let err: ToolError = .unsupportedOperation("not supported")
        XCTAssertEqual(err.errorDescription, "not supported")
    }

    func test_dependencyMissing_hasLocalizedDescription() {
        let err: ToolError = .dependencyMissing("openssl")
        XCTAssertEqual(err.errorDescription, "openssl")
    }

    func test_storageFailure_hasLocalizedDescription() {
        let err: ToolError = .storageFailure(message: "disk full")
        XCTAssertEqual(err.errorDescription, "disk full")
    }

    func test_equatable_differentCases_areNotEqual() {
        let a: ToolError = .invalidInput(reason: "x")
        let b: ToolError = .unsupportedOperation("x")
        XCTAssertNotEqual(a, b)
    }
}
