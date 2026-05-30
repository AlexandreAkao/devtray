@testable import DevTrayCore
import XCTest

final class TrialTrackerTests: XCTestCase {
    private var kc: InMemoryKeychain!
    private var nowBox: NowBox!
    private var tracker: TrialTracker!
    private let day: TimeInterval = 86_400

    override func setUp() async throws {
        kc = InMemoryKeychain()
        nowBox = NowBox(value: Date(timeIntervalSince1970: 1_748_560_000))
        tracker = TrialTracker(keychain: kc, clock: { [nowBox] in nowBox!.value })
    }

    func test_ensureTrialStarted_firstCall_writesTrialStart() async throws {
        let start = try await tracker.ensureTrialStarted()
        XCTAssertEqual(start, nowBox.value)
    }

    func test_ensureTrialStarted_secondCall_returnsExistingStart() async throws {
        let first = try await tracker.ensureTrialStarted()
        nowBox.value = nowBox.value.addingTimeInterval(day * 3)
        let second = try await tracker.ensureTrialStarted()
        XCTAssertEqual(first, second)
    }

    func test_currentStatus_freshTrial_returns14DaysLeftNotExpired() async throws {
        _ = try await tracker.ensureTrialStarted()
        let (daysLeft, expired) = try await tracker.currentStatus()
        XCTAssertEqual(daysLeft, 14)
        XCTAssertFalse(expired)
    }

    func test_currentStatus_after7days_returns7DaysLeft() async throws {
        _ = try await tracker.ensureTrialStarted()
        nowBox.value = nowBox.value.addingTimeInterval(day * 7)
        let (daysLeft, expired) = try await tracker.currentStatus()
        XCTAssertEqual(daysLeft, 7)
        XCTAssertFalse(expired)
    }

    func test_currentStatus_after14days_returns0DaysLeftExpired() async throws {
        _ = try await tracker.ensureTrialStarted()
        nowBox.value = nowBox.value.addingTimeInterval(day * 14)
        let (daysLeft, expired) = try await tracker.currentStatus()
        XCTAssertEqual(daysLeft, 0)
        XCTAssertTrue(expired)
    }

    func test_currentStatus_after15days_returns0DaysLeftExpired() async throws {
        _ = try await tracker.ensureTrialStarted()
        nowBox.value = nowBox.value.addingTimeInterval(day * 15)
        let (daysLeft, expired) = try await tracker.currentStatus()
        XCTAssertEqual(daysLeft, 0)
        XCTAssertTrue(expired)
    }

    func test_detectClockSetback_noLastSeen_returnsFalse() async throws {
        let setback = try await tracker.detectClockSetback()
        XCTAssertFalse(setback)
    }

    func test_detectClockSetback_recordedThenForwardClock_returnsFalse() async throws {
        try await tracker.recordLastSeen()
        nowBox.value = nowBox.value.addingTimeInterval(day)
        let setback = try await tracker.detectClockSetback()
        XCTAssertFalse(setback)
    }

    func test_detectClockSetback_recordedThenBackwardOver1h_returnsTrue() async throws {
        try await tracker.recordLastSeen()
        nowBox.value = nowBox.value.addingTimeInterval(-3601) // 1h + 1s backward
        let setback = try await tracker.detectClockSetback()
        XCTAssertTrue(setback)
    }

    func test_detectClockSetback_recordedThenBackwardUnder1h_returnsFalse() async throws {
        try await tracker.recordLastSeen()
        nowBox.value = nowBox.value.addingTimeInterval(-1800) // 30 min backward (grace)
        let setback = try await tracker.detectClockSetback()
        XCTAssertFalse(setback)
    }
}

private final class NowBox {
    var value: Date
    init(value: Date) { self.value = value }
}
