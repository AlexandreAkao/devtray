import Foundation

@MainActor
public final class SpotlightRanker {
    private let registry: ToolRegistry
    private let usage: any UsageStore

    public init(registry: ToolRegistry, usage: any UsageStore) {
        self.registry = registry
        self.usage = usage
    }

    public func rank(
        query: String,
        clipboard: String?,
        limit: Int = 8,
        now: Date = .now
    ) async -> [SpotlightResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty
            ? await rankWithoutQuery(clipboard: clipboard, limit: limit, now: now)
            : await rankWithQuery(query: q, clipboard: clipboard, limit: limit, now: now)
    }

    // MARK: - No query path

    private func rankWithoutQuery(
        clipboard: String?,
        limit: Int,
        now: Date
    ) async -> [SpotlightResult] {
        let matchers: [(AnyTool, ClipboardMatchScore)] = registry.tools.compactMap { tool in
            guard let clipboard, let score = tool.clipboardMatch(clipboard) else { return nil }
            return (tool, score)
        }

        if let top = await pickTopMatcher(matchers, now: now) {
            let restLimit = max(0, limit - 1)
            let rest = (try? await usage.topTools(window: .lastDays(7), limit: restLimit, now: now))
                ?? []
            let restResults = rest
                .filter { $0.toolID != top.id }
                .map { SpotlightResult(toolID: $0.toolID, fromClipboard: false) }
            return Array(
                ([SpotlightResult(toolID: top.id, fromClipboard: true)] + restResults).prefix(limit)
            )
        }

        let ranks = (try? await usage.topTools(window: .lastDays(7), limit: limit, now: now)) ?? []
        return ranks.map { SpotlightResult(toolID: $0.toolID, fromClipboard: false) }
    }

    private func pickTopMatcher(
        _ matchers: [(AnyTool, ClipboardMatchScore)],
        now: Date
    ) async -> AnyTool? {
        guard !matchers.isEmpty else { return nil }
        let usageRank = await usageRankMap(window: .allTime, now: now)
        let sorted = matchers.sorted { a, b in
            if a.1.confidence != b.1.confidence {
                return a.1.confidence > b.1.confidence
            }
            let aRank = usageRank[a.0.id] ?? .max
            let bRank = usageRank[b.0.id] ?? .max
            if aRank != bRank { return aRank < bRank }
            return a.0.id.rawValue < b.0.id.rawValue
        }
        return sorted.first?.0
    }

    // MARK: - With query path

    private func rankWithQuery(
        query: String,
        clipboard: String?,
        limit: Int,
        now: Date
    ) async -> [SpotlightResult] {
        let matched: [(AnyTool, Int)] = registry.tools.compactMap { tool in
            guard let s = fuzzyScore(
                query: query,
                displayName: tool.displayName,
                keywords: tool.keywords
            ) else { return nil }
            return (tool, s)
        }
        let usageRank = await usageRankMap(window: .allTime, now: now)
        let ordered = matched.sorted { a, b in
            if a.1 != b.1 { return a.1 > b.1 }
            let aRank = usageRank[a.0.id] ?? .max
            let bRank = usageRank[b.0.id] ?? .max
            if aRank != bRank { return aRank < bRank }
            return a.0.id.rawValue < b.0.id.rawValue
        }
        return ordered.prefix(limit).map { tool, _ in
            let badge: Bool
            if let clipboard {
                badge = tool.clipboardMatch(clipboard) != nil
            } else {
                badge = false
            }
            return SpotlightResult(toolID: tool.id, fromClipboard: badge)
        }
    }

    // MARK: - Helpers

    private func usageRankMap(window: UsageWindow, now: Date) async -> [ToolID: Int] {
        let ranks = (try? await usage.topTools(window: window, limit: 100, now: now)) ?? []
        var map: [ToolID: Int] = [:]
        for (index, rank) in ranks.enumerated() {
            map[rank.toolID] = index
        }
        return map
    }
}
