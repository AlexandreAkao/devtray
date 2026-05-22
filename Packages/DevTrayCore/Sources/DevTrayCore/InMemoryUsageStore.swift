import Foundation

public actor InMemoryUsageStore: UsageStore {
    private var rows: [(toolID: ToolID, usedAt: Date)] = []

    public init() {}

    public func record(toolID: ToolID, at date: Date) async {
        rows.append((toolID, date))
    }

    public func topTools(window: UsageWindow, limit: Int, now: Date) async throws -> [ToolUsageRank] {
        let primary = rank(rows: filter(rows, window: window, now: now), limit: limit, exclude: [])
        if primary.count >= limit || window == .allTime { return primary }
        let used = Set(primary.map(\.toolID))
        let extra = rank(rows: rows, limit: limit - primary.count, exclude: used)
        return primary + extra
    }

    private func filter(_ rows: [(toolID: ToolID, usedAt: Date)],
                        window: UsageWindow,
                        now: Date) -> [(toolID: ToolID, usedAt: Date)] {
        switch window {
        case .allTime:
            return rows
        case .lastDays(let days):
            let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
            return rows.filter { $0.usedAt > cutoff }
        }
    }

    private func rank(rows: [(toolID: ToolID, usedAt: Date)],
                      limit: Int,
                      exclude: Set<ToolID>) -> [ToolUsageRank] {
        var counts: [ToolID: Int] = [:]
        for row in rows where !exclude.contains(row.toolID) {
            counts[row.toolID, default: 0] += 1
        }
        let sorted = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key.rawValue < rhs.key.rawValue
        }
        return sorted.prefix(limit).map {
            ToolUsageRank(toolID: $0.key, count: $0.value)
        }
    }
}
