import XCTest
@testable import DevTrayStorage

final class SnippetHelpersTests: XCTestCase {
    func test_tagCodec_roundTrips() {
        let tags = ["swift", "ios", "café"]
        let json = SnippetTagCodec.encode(tags)
        XCTAssertEqual(SnippetTagCodec.decode(json), tags)
    }

    func test_tagCodec_empty() {
        XCTAssertEqual(SnippetTagCodec.encode([]), "[]")
        XCTAssertEqual(SnippetTagCodec.decode("[]"), [])
    }

    func test_tagCodec_decodesGarbageAsEmpty() {
        XCTAssertEqual(SnippetTagCodec.decode("not json"), [])
    }

    func test_ftsQuery_emptyReturnsNil() {
        XCTAssertNil(FTSQuery.sanitize("   "))
        XCTAssertNil(FTSQuery.sanitize(""))
    }

    func test_ftsQuery_singleToken_prefixQuoted() {
        XCTAssertEqual(FTSQuery.sanitize("hello"), "\"hello\"*")
    }

    func test_ftsQuery_multipleTokens() {
        XCTAssertEqual(FTSQuery.sanitize("foo bar"), "\"foo\"* \"bar\"*")
    }

    func test_ftsQuery_escapesEmbeddedQuotes() {
        XCTAssertEqual(FTSQuery.sanitize("a\"b"), "\"a\"\"b\"*")
    }
}
