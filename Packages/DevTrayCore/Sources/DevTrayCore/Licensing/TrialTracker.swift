import Combine
import Foundation

public actor TrialTracker: ObservableObject {
    private let keychain: KeychainProtocol
    private let clock: @Sendable () -> Date
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private static let trialDays = 14
    private static let clockSetbackGraceSeconds: TimeInterval = 3600 // 1h

    public init(keychain: KeychainProtocol = SystemKeychain(),
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.keychain = keychain
        self.clock = clock
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        self.encoder = enc
        self.decoder = dec
    }

    /// Returns the trial start, writing it on first call.
    @discardableResult
    public func ensureTrialStarted() throws -> Date {
        if let existing = try storedTrialStart() { return existing }
        let now = clock()
        try keychain.set(encoder.encode(now), account: Account.trialStart)
        return now
    }

    /// Returns (daysLeft 0...14, expired Bool).
    public func currentStatus() throws -> (daysLeft: Int, expired: Bool) {
        let start = try ensureTrialStarted()
        let elapsed = clock().timeIntervalSince(start)
        let elapsedDays = Int(floor(elapsed / 86_400))
        let daysLeft = max(0, Self.trialDays - elapsedDays)
        let expired = daysLeft == 0
        return (daysLeft, expired)
    }

    /// True iff `now < last_seen_at - 1h` (clock setback past grace).
    public func detectClockSetback() throws -> Bool {
        guard let lastSeen = try storedLastSeen() else { return false }
        return clock() < lastSeen.addingTimeInterval(-Self.clockSetbackGraceSeconds)
    }

    public func recordLastSeen() throws {
        try keychain.set(encoder.encode(clock()), account: Account.lastSeenAt)
    }

    // MARK: - Private

    private func storedTrialStart() throws -> Date? {
        guard let data = try keychain.get(account: Account.trialStart) else { return nil }
        return try? decoder.decode(Date.self, from: data)
    }

    private func storedLastSeen() throws -> Date? {
        guard let data = try keychain.get(account: Account.lastSeenAt) else { return nil }
        return try? decoder.decode(Date.self, from: data)
    }

    private enum Account {
        static let trialStart = "trial_start"
        static let lastSeenAt = "last_seen_at"
    }
}
