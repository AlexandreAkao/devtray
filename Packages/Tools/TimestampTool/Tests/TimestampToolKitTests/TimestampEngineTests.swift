import XCTest
@testable import TimestampToolKit
import DevTrayCore

final class TimestampEngineTests: XCTestCase {
    // MARK: - Numeric parsing

    func test_parse_tenDigitSeconds_returnsBreakdown() {
        guard case .success(let b) = TimestampEngine.parse("1716300730") else {
            XCTFail(); return
        }
        XCTAssertEqual(b.epochSeconds, 1716300730)
        XCTAssertEqual(b.epochMillis, 1716300730000)
        XCTAssertEqual(b.isoUTC, "2024-05-21T14:12:10Z")
        XCTAssertFalse(b.isoLocal.isEmpty)
    }

    func test_parse_thirteenDigitMillis_returnsBreakdown() {
        guard case .success(let b) = TimestampEngine.parse("1716300730123") else {
            XCTFail(); return
        }
        XCTAssertEqual(b.epochSeconds, 1716300730)
        XCTAssertEqual(b.epochMillis, 1716300730123)
    }

    func test_parse_nineDigits_returnsParseFailure() {
        if case .failure(.parseFailure) = TimestampEngine.parse("123456789") { return }
        XCTFail("expected parseFailure for 9-digit numeric input")
    }

    func test_parse_elevenDigits_returnsParseFailure() {
        if case .failure(.parseFailure) = TimestampEngine.parse("12345678901") { return }
        XCTFail("expected parseFailure for 11-digit numeric input")
    }

    func test_parse_twelveDigits_returnsParseFailure() {
        if case .failure(.parseFailure) = TimestampEngine.parse("123456789012") { return }
        XCTFail("expected parseFailure for 12-digit numeric input")
    }

    func test_parse_signedNumber_returnsParseFailure() {
        // Signed numbers are not "all digits"; fall through to ISO parse which fails.
        if case .failure(.parseFailure) = TimestampEngine.parse("-1234567890") { return }
        XCTFail("expected parseFailure for signed numeric input")
    }

    // MARK: - ISO 8601 parsing

    func test_parse_isoUTC_returnsBreakdown() {
        guard case .success(let b) = TimestampEngine.parse("2024-05-21T14:12:10Z") else {
            XCTFail(); return
        }
        XCTAssertEqual(b.epochSeconds, 1716300730)
        XCTAssertEqual(b.isoUTC, "2024-05-21T14:12:10Z")
    }

    func test_parse_isoWithFractional_preservesMillis() {
        guard case .success(let b) = TimestampEngine.parse("2024-05-21T14:12:10.500Z") else {
            XCTFail(); return
        }
        XCTAssertEqual(b.epochSeconds, 1716300730)
        XCTAssertEqual(b.epochMillis, 1716300730500)
    }

    func test_parse_isoWithOffset_roundTripsToUTC() {
        // 2024-05-21T11:12:10-03:00 == 2024-05-21T14:12:10Z
        guard case .success(let b) = TimestampEngine.parse("2024-05-21T11:12:10-03:00") else {
            XCTFail(); return
        }
        XCTAssertEqual(b.epochSeconds, 1716300730)
        XCTAssertEqual(b.isoUTC, "2024-05-21T14:12:10Z")
    }

    // MARK: - Invalid

    func test_parse_garbage_returnsParseFailure() {
        if case .failure(.parseFailure) = TimestampEngine.parse("not a date") { return }
        XCTFail("expected parseFailure")
    }

    func test_parse_empty_returnsInvalidInput() {
        if case .failure(.invalidInput) = TimestampEngine.parse("") { return }
        XCTFail("expected invalidInput")
    }

    func test_parse_whitespaceOnly_returnsInvalidInput() {
        if case .failure(.invalidInput) = TimestampEngine.parse("   \n") { return }
        XCTFail("expected invalidInput")
    }

    func test_parse_trimsWhitespace() {
        guard case .success(let b) = TimestampEngine.parse("  1716300730  ") else {
            XCTFail(); return
        }
        XCTAssertEqual(b.epochSeconds, 1716300730)
    }

    // MARK: - now()

    func test_now_isCloseToCurrentTime() {
        let before = Int64(Date().timeIntervalSince1970)
        let b = TimestampEngine.now()
        let after = Int64(Date().timeIntervalSince1970)
        XCTAssertGreaterThanOrEqual(b.epochSeconds, before)
        XCTAssertLessThanOrEqual(b.epochSeconds, after + 1)
        XCTAssertFalse(b.isoUTC.isEmpty)
        XCTAssertFalse(b.isoLocal.isEmpty)
    }
}
