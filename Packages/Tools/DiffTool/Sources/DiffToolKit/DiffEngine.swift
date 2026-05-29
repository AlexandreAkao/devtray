import Foundation

public enum DiffRowKind: String, Sendable, Equatable {
    case equal, insert, delete
}

public struct DiffRow: Equatable, Sendable {
    public let kind: DiffRowKind
    public let text: String
    public let leftLine: Int?
    public let rightLine: Int?
    public init(kind: DiffRowKind, text: String, leftLine: Int?, rightLine: Int?) {
        self.kind = kind; self.text = text; self.leftLine = leftLine; self.rightLine = rightLine
    }
}

public struct DiffHunk: Equatable, Sendable {
    public let header: String
    public let rows: [DiffRow]
    public init(header: String, rows: [DiffRow]) {
        self.header = header; self.rows = rows
    }
}

public enum DiffEngine {
    public static func diffLines(_ a: String, _ b: String) -> [DiffRow] {
        let left = splitLines(a)
        let right = splitLines(b)
        let n = left.count, m = right.count

        // LCS length table, sized (n+1) x (m+1), filled bottom-up.
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0, m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    dp[i][j] = left[i] == right[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }

        var rows: [DiffRow] = []
        var i = 0, j = 0, leftNo = 1, rightNo = 1
        while i < n, j < m {
            if left[i] == right[j] {
                rows.append(DiffRow(kind: .equal, text: left[i], leftLine: leftNo, rightLine: rightNo))
                i += 1; j += 1; leftNo += 1; rightNo += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                rows.append(DiffRow(kind: .delete, text: left[i], leftLine: leftNo, rightLine: nil))
                i += 1; leftNo += 1
            } else {
                rows.append(DiffRow(kind: .insert, text: right[j], leftLine: nil, rightLine: rightNo))
                j += 1; rightNo += 1
            }
        }
        while i < n { rows.append(DiffRow(kind: .delete, text: left[i], leftLine: leftNo, rightLine: nil)); i += 1; leftNo += 1 }
        while j < m { rows.append(DiffRow(kind: .insert, text: right[j], leftLine: nil, rightLine: rightNo)); j += 1; rightNo += 1 }
        return rows
    }

    public static func unifiedHunks(_ a: String, _ b: String, context: Int = 3) -> [DiffHunk] {
        let rows = diffLines(a, b)
        let changed = rows.indices.filter { rows[$0].kind != .equal }
        guard !changed.isEmpty else { return [] }

        var hunks: [DiffHunk] = []
        var start = max(0, changed[0] - context)
        var end = min(rows.count - 1, changed[0] + context)
        for k in 1 ..< changed.count {
            let idx = changed[k]
            if idx - context <= end + 1 {
                end = min(rows.count - 1, idx + context)
            } else {
                hunks.append(makeHunk(rows, start, end))
                start = max(0, idx - context)
                end = min(rows.count - 1, idx + context)
            }
        }
        hunks.append(makeHunk(rows, start, end))
        return hunks
    }

    private static func makeHunk(_ rows: [DiffRow], _ start: Int, _ end: Int) -> DiffHunk {
        let slice = Array(rows[start ... end])
        let leftStart = slice.compactMap(\.leftLine).first ?? 0
        let rightStart = slice.compactMap(\.rightLine).first ?? 0
        let leftCount = slice.filter { $0.leftLine != nil }.count
        let rightCount = slice.filter { $0.rightLine != nil }.count
        return DiffHunk(header: "@@ -\(leftStart),\(leftCount) +\(rightStart),\(rightCount) @@", rows: slice)
    }

    private static func splitLines(_ s: String) -> [String] {
        guard !s.isEmpty else { return [] }
        var parts = s.components(separatedBy: "\n")
        if parts.last == "" { parts.removeLast() } // drop the empty token a terminal newline produces
        return parts
    }
}
