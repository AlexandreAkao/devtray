public struct TimestampBreakdown: Equatable, Sendable {
    public let epochSeconds: Int64
    public let epochMillis: Int64
    public let isoUTC: String
    public let isoLocal: String

    public init(epochSeconds: Int64, epochMillis: Int64, isoUTC: String, isoLocal: String) {
        self.epochSeconds = epochSeconds
        self.epochMillis = epochMillis
        self.isoUTC = isoUTC
        self.isoLocal = isoLocal
    }
}
