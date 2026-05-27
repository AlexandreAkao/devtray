import XCTest
import DevTrayCore
@testable import RegexToolKit

final class RegexEngineTests: XCTestCase {
    func test_findsAllMatches() {
        guard case .success(let matches) = RegexEngine.evaluate(pattern: "\\d+", flags: [], input: "a1b22c") else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(matches.map(\.value), ["1", "22"])
    }

    func test_captureGroups() {
        guard case .success(let matches) = RegexEngine.evaluate(pattern: "(\\w)(\\d)", flags: [], input: "a1") else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].groups.map(\.value), ["a1", "a", "1"])
    }

    func test_nonParticipatingGroupIsNil() {
        guard case .success(let matches) = RegexEngine.evaluate(pattern: "(a)|(b)", flags: [], input: "b") else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(matches[0].groups[1].value, nil)
        XCTAssertEqual(matches[0].groups[2].value, "b")
    }

    func test_caseInsensitiveFlag() {
        guard case .success(let m) = RegexEngine.evaluate(pattern: "abc", flags: [.caseInsensitive], input: "ABC") else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(m.count, 1)
    }

    func test_multilineFlag() {
        guard case .success(let m) = RegexEngine.evaluate(pattern: "^b", flags: [.multiline], input: "a\nb") else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(m.count, 1)
    }

    func test_dotMatchesLineSeparatorsFlag() {
        guard case .success(let on) = RegexEngine.evaluate(pattern: "a.b", flags: [.dotMatchesLineSeparators], input: "a\nb"),
              case .success(let off) = RegexEngine.evaluate(pattern: "a.b", flags: [], input: "a\nb") else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(on.count, 1)
        XCTAssertEqual(off.count, 0)
    }

    func test_replaceWithTemplate() {
        guard case .success(let out) = RegexEngine.replace(pattern: "(\\d)", flags: [], input: "a1b2", template: "[$1]") else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(out, "a[1]b[2]")
    }

    func test_invalidPatternFails() {
        guard case .failure(let error) = RegexEngine.evaluate(pattern: "(", flags: [], input: "x") else {
            return XCTFail("expected failure")
        }
        guard case ToolError.parseFailure = error else { return XCTFail("expected parseFailure") }
    }

    func test_emptyPatternIsEmptyResult() {
        guard case .success(let m) = RegexEngine.evaluate(pattern: "", flags: [], input: "anything") else {
            return XCTFail("expected success")
        }
        XCTAssertTrue(m.isEmpty)
    }
}
