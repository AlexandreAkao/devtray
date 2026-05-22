import Foundation

public protocol UsageStore: Sendable {
    func record(toolID: ToolID, at date: Date) async
    func topTools(window: UsageWindow, limit: Int, now: Date) async throws -> [ToolUsageRank]
}

public enum UsageWindow: Sendable, Equatable {
    case lastDays(Int)
    case allTime
}

public struct ToolUsageRank: Hashable, Sendable {
    public let toolID: ToolID
    public let count: Int

    public init(toolID: ToolID, count: Int) {
        self.toolID = toolID
        self.count = count
    }
}
