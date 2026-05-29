@testable import CronToolKit
import DevTrayCore
import XCTest

final class CronEngineTests: XCTestCase {
    private func parsed(_ expr: String) -> CronExpression? {
        if case .success(let e) = CronEngine.parse(expr) { return e }
        return nil
    }

    func test_everyField() {
        let e = parsed("* * * * *")
        XCTAssertEqual(e?.minutes.count, 60)
        XCTAssertEqual(e?.hours.count, 24)
        XCTAssertEqual(e?.daysOfMonth.count, 31)
        XCTAssertEqual(e?.months.count, 12)
        XCTAssertEqual(e?.daysOfWeek.count, 7)
    }

    func test_specificAndRange() {
        let e = parsed("0 9 * * 1-5")
        XCTAssertEqual(e?.minutes, [0])
        XCTAssertEqual(e?.hours, [9])
        XCTAssertEqual(e?.daysOfWeek, [1, 2, 3, 4, 5])
    }

    func test_step() {
        XCTAssertEqual(parsed("*/15 * * * *")?.minutes, [0, 15, 30, 45])
    }

    func test_macroDaily() {
        let e = parsed("@daily")
        XCTAssertEqual(e?.minutes, [0]); XCTAssertEqual(e?.hours, [0])
        XCTAssertEqual(e?.daysOfMonth.count, 31)
    }

    func test_names() {
        let e = parsed("0 0 * JAN MON")
        XCTAssertEqual(e?.months, [1]); XCTAssertEqual(e?.daysOfWeek, [1])
    }

    func test_sundayAsSeven() {
        XCTAssertEqual(parsed("0 0 * * 7")?.daysOfWeek, [0])
    }

    func test_outOfRangeFails() {
        guard case .failure(let error) = CronEngine.parse("60 * * * *") else { return XCTFail("expected failure") }
        guard case ToolError.parseFailure = error else { return XCTFail("expected parseFailure") }
    }

    func test_wrongFieldCountFails() {
        guard case .failure = CronEngine.parse("* * *") else { return XCTFail("expected failure") }
    }

    func test_nextExecutions() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let from = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 0, minute: 0))!
        let e = parsed("0 9 * * *")!
        let next = CronEngine.nextExecutions(e, from: from, count: 2, timeZone: TimeZone(identifier: "UTC")!)
        let expected1 = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 9, minute: 0))!
        let expected2 = cal.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 9, minute: 0))!
        XCTAssertEqual(next, [expected1, expected2])
    }

    func test_humanDescription_time() {
        XCTAssertTrue(CronEngine.humanDescription(parsed("0 9 * * 1-5")!).contains("09:00"))
        XCTAssertTrue(CronEngine.humanDescription(parsed("0 9 * * 1-5")!).contains("Mon"))
        XCTAssertTrue(CronEngine.humanDescription(parsed("@daily")!).contains("00:00"))
    }

    func test_stepWithStartValue() {
        // "5/15" → 5, 20, 35, 50 (start value with step)
        XCTAssertEqual(parsed("5/15 * * * *")?.minutes, [5, 20, 35, 50])
    }

    func test_rangeWithStep() {
        // "0-30/10" → 0, 10, 20, 30
        XCTAssertEqual(parsed("0-30/10 * * * *")?.minutes, [0, 10, 20, 30])
    }

    func test_nextExecutions_excludesFromItself() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        // from is EXACTLY a fire time; the first result must be the NEXT day, not `from`.
        let from = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 9, minute: 0))!
        let e = parsed("0 9 * * *")!
        let next = CronEngine.nextExecutions(e, from: from, count: 1, timeZone: TimeZone(identifier: "UTC")!)
        let expected = cal.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 9, minute: 0))!
        XCTAssertEqual(next, [expected])
    }
}
