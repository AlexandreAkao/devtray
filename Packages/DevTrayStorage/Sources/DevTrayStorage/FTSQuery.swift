import Foundation

enum FTSQuery {
    /// Turns arbitrary user input into a safe FTS5 prefix-match expression, or
    /// `nil` when there are no searchable tokens. Each whitespace-separated token
    /// is double-quoted (embedded quotes doubled per FTS5 rules) with a trailing
    /// `*` for prefix matching.
    static func sanitize(_ raw: String) -> String? {
        let tokens = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }
        return tokens.map { token in
            let escaped = token.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\"*"
        }.joined(separator: " ")
    }
}
