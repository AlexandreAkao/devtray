import DevTrayCore
import Foundation
import GRDB
import os

public final class SQLiteUsageStore: UsageStore, @unchecked Sendable {
    private let dbQueue: DatabaseQueue
    private let logger = Logger(subsystem: "com.devtray.app", category: "storage")

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public static func openDefault() throws -> SQLiteUsageStore {
        let url = try DatabaseOpener.defaultURL()
        let queue = try DatabaseOpener.open(at: url)
        var migrator = DatabaseMigrator()
        Migrations.register(on: &migrator)
        try migrator.migrate(queue)
        return SQLiteUsageStore(dbQueue: queue)
    }

    public func record(toolID: ToolID, at date: Date) async {
        do {
            try await dbQueue.write { db in
                try db.execute(
                    sql: "INSERT INTO tool_usage (tool_id, used_at) VALUES (?, ?)",
                    arguments: [toolID.rawValue, date.timeIntervalSince1970]
                )
            }
        } catch {
            logger.error("usage record failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func topTools(window: UsageWindow,
                         limit: Int,
                         now: Date) async throws -> [ToolUsageRank] {
        let primary = try await fetchRanks(window: window, limit: limit, now: now, exclude: [])
        if primary.count >= limit || window == .allTime { return primary }
        let used = Set(primary.map(\.toolID))
        let extra = try await fetchRanks(window: .allTime, limit: limit - primary.count, now: now, exclude: used)
        return primary + extra
    }

    // MARK: - Internal helpers

    private func fetchRanks(window: UsageWindow,
                            limit: Int,
                            now: Date,
                            exclude: Set<ToolID>) async throws -> [ToolUsageRank] {
        try await dbQueue.read { db in
            var sql = "SELECT tool_id, COUNT(*) AS uses FROM tool_usage"
            var args: [DatabaseValueConvertible] = []
            var wheres: [String] = []

            if case .lastDays(let days) = window {
                let cutoff = now.addingTimeInterval(-Double(days) * 86_400).timeIntervalSince1970
                wheres.append("used_at > ?")
                args.append(cutoff)
            }
            if !exclude.isEmpty {
                let placeholders = exclude.map { _ in "?" }.joined(separator: ",")
                wheres.append("tool_id NOT IN (\(placeholders))")
                args.append(contentsOf: exclude.map(\.rawValue))
            }
            if !wheres.isEmpty {
                sql += " WHERE " + wheres.joined(separator: " AND ")
            }
            sql += " GROUP BY tool_id ORDER BY uses DESC, tool_id ASC LIMIT ?"
            args.append(limit)

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
            return rows.map { row in
                ToolUsageRank(
                    toolID: ToolID(rawValue: row["tool_id"]),
                    count: row["uses"]
                )
            }
        }
    }

    // MARK: - Test helper (not part of the UsageStore protocol)

    struct RawRow: Equatable {
        let toolID: ToolID
        let usedAt: Date
    }

    func debugDumpAllRows() async throws -> [RawRow] {
        try await dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT tool_id, used_at FROM tool_usage ORDER BY rowid")
            return rows.map { row in
                RawRow(
                    toolID: ToolID(rawValue: row["tool_id"]),
                    usedAt: Date(timeIntervalSince1970: row["used_at"])
                )
            }
        }
    }
}
