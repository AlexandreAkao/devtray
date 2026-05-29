/// Subsequence fuzzy match. Returns nil if no match, otherwise an opaque score
/// (higher = better). Used by SpotlightRanker; not intended for external use.
///
/// Scoring:
/// - Each subsequence match against displayName scores 100.
/// - +50 bonus if the query is a case-insensitive prefix of the displayName.
/// - If displayName does not match, each keyword is tried; the highest match
///   scores 50 (no prefix bonus). Keyword matches always rank below displayName
///   matches.
func fuzzyScore(query: String, displayName: String, keywords: [String]) -> Int? {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !q.isEmpty else { return nil }

    let dn = displayName.lowercased()
    if isSubsequence(q, of: dn) {
        var score = 100
        if dn.hasPrefix(q) {
            score += 50
        }
        return score
    }

    for keyword in keywords {
        if isSubsequence(q, of: keyword.lowercased()) {
            return 50
        }
    }
    return nil
}

private func isSubsequence(_ needle: String, of haystack: String) -> Bool {
    var hi = haystack.startIndex
    for nc in needle {
        guard let found = haystack[hi...].firstIndex(of: nc) else { return false }
        hi = haystack.index(after: found)
    }
    return true
}
