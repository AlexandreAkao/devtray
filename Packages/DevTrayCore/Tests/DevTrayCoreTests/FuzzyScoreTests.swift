@testable import DevTrayCore
import XCTest

final class FuzzyScoreTests: XCTestCase {
    func test_exactPrefix_scoresHigherThanInfixSubsequence() {
        let prefix = fuzzyScore(query: "jw", displayName: "JWT", keywords: [])
        let infix = fuzzyScore(query: "jw", displayName: "Hijwacker", keywords: [])
        XCTAssertNotNil(prefix)
        XCTAssertNotNil(infix)
        XCTAssertGreaterThan(prefix!, infix!)
    }

    func test_noMatch_returnsNil() {
        XCTAssertNil(fuzzyScore(query: "xyz", displayName: "JWT", keywords: ["token"]))
    }

    func test_caseInsensitive() {
        XCTAssertNotNil(fuzzyScore(query: "JWT", displayName: "jwt", keywords: []))
    }

    func test_keywordMatch_scoresLowerThanDisplayName() {
        let dn = fuzzyScore(query: "tok", displayName: "Token Inspector", keywords: [])
        let kw = fuzzyScore(query: "tok", displayName: "JWT", keywords: ["token"])
        XCTAssertNotNil(dn)
        XCTAssertNotNil(kw)
        XCTAssertGreaterThan(dn!, kw!)
    }

    func test_emptyQuery_returnsNil() {
        XCTAssertNil(fuzzyScore(query: "", displayName: "JWT", keywords: []))
    }

    func test_subsequenceMatch_orderMatters() {
        XCTAssertNil(fuzzyScore(query: "tj", displayName: "JWT", keywords: []))
    }
}
