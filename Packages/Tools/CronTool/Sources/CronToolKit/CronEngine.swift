import Foundation
import DevTrayCore

public struct CronExpression: Equatable, Sendable {
    public let minutes: Set<Int>       // 0–59
    public let hours: Set<Int>         // 0–23
    public let daysOfMonth: Set<Int>   // 1–31
    public let months: Set<Int>        // 1–12
    public let daysOfWeek: Set<Int>    // 0–6 (0 = Sunday)
}

public enum CronEngine {
    private static let monthNames = ["JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
                                     "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12]
    private static let dowNames = ["SUN": 0, "MON": 1, "TUE": 2, "WED": 3, "THU": 4, "FRI": 5, "SAT": 6]

    public static func parse(_ expr: String) -> Result<CronExpression, ToolError> {
        let trimmed = expr.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = macroExpansion(trimmed) ?? trimmed
        let fields = normalized.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard fields.count == 5 else {
            return .failure(.parseFailure(reason: "Expected 5 fields, found \(fields.count).",
                                          hint: "Format: minute hour day-of-month month day-of-week"))
        }
        guard let minutes = parseField(fields[0], min: 0, max: 59) else { return fieldError("minute", fields[0]) }
        guard let hours = parseField(fields[1], min: 0, max: 23) else { return fieldError("hour", fields[1]) }
        guard let dom = parseField(fields[2], min: 1, max: 31) else { return fieldError("day-of-month", fields[2]) }
        guard let months = parseField(fields[3], min: 1, max: 12, names: monthNames) else { return fieldError("month", fields[3]) }
        guard var dow = parseField(fields[4], min: 0, max: 7, names: dowNames) else { return fieldError("day-of-week", fields[4]) }
        if dow.contains(7) { dow.remove(7); dow.insert(0) }
        return .success(CronExpression(minutes: minutes, hours: hours, daysOfMonth: dom, months: months, daysOfWeek: dow))
    }

    public static func humanDescription(_ e: CronExpression) -> String {
        var clauses: [String] = []
        if e.minutes.count == 1, e.hours.count == 1 {
            clauses.append(String(format: "At %02d:%02d", e.hours.first!, e.minutes.first!))
        } else if e.hours.count == 24, e.minutes.count == 60 {
            clauses.append("Every minute")
        } else if e.hours.count == 24 {
            clauses.append("At minute \(list(e.minutes)) of every hour")
        } else {
            clauses.append("At minute \(list(e.minutes)) past hour \(list(e.hours))")
        }
        if e.daysOfWeek.count < 7 {
            clauses.append("on " + e.daysOfWeek.sorted().map(dayName).joined(separator: ", "))
        }
        if e.daysOfMonth.count < 31 {
            clauses.append("on day-of-month \(list(e.daysOfMonth))")
        }
        if e.months.count < 12 {
            clauses.append("in " + e.months.sorted().map(monthName).joined(separator: ", "))
        }
        return clauses.joined(separator: " ")
    }

    public static func nextExecutions(_ e: CronExpression, from: Date, count: Int = 5,
                                      timeZone: TimeZone = .current) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let startComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: from)
        guard let minuteBoundary = cal.date(from: startComps),
              var t = cal.date(byAdding: .minute, value: 1, to: minuteBoundary) else { return [] }

        let domRestricted = e.daysOfMonth.count != 31
        let dowRestricted = e.daysOfWeek.count != 7
        var results: [Date] = []
        var iterations = 0
        // ~1 year of minutes. Bounds worst-case work on the main thread for valid-but-never-firing
        // expressions (e.g. "0 0 30 2 *"); expressions that don't fire within a year preview nothing.
        let maxIterations = 366 * 24 * 60

        while results.count < count && iterations < maxIterations {
            let c = cal.dateComponents([.minute, .hour, .day, .month, .weekday], from: t)
            let weekday0 = (c.weekday! - 1)      // Calendar: 1 = Sunday → 0
            let dayOK: Bool
            if domRestricted && dowRestricted { dayOK = e.daysOfMonth.contains(c.day!) || e.daysOfWeek.contains(weekday0) }
            else if domRestricted { dayOK = e.daysOfMonth.contains(c.day!) }
            else if dowRestricted { dayOK = e.daysOfWeek.contains(weekday0) }
            else { dayOK = true }

            if e.minutes.contains(c.minute!), e.hours.contains(c.hour!), e.months.contains(c.month!), dayOK {
                results.append(t)
            }
            guard let nextT = cal.date(byAdding: .minute, value: 1, to: t) else { break }
            t = nextT
            iterations += 1
        }
        return results
    }

    // MARK: - Field parsing

    private static func parseField(_ field: String, min: Int, max: Int, names: [String: Int] = [:]) -> Set<Int>? {
        var result = Set<Int>()
        for term in field.split(separator: ",") {
            guard let vals = parseTerm(String(term), min: min, max: max, names: names) else { return nil }
            result.formUnion(vals)
        }
        return result.isEmpty ? nil : result
    }

    private static func parseTerm(_ term: String, min: Int, max: Int, names: [String: Int]) -> Set<Int>? {
        var base = term
        var step = 1
        if let slash = term.firstIndex(of: "/") {
            base = String(term[..<slash])
            guard let s = Int(term[term.index(after: slash)...]), s > 0 else { return nil }
            step = s
        }
        var lo: Int, hi: Int
        if base == "*" {
            lo = min; hi = max
        } else if let dash = splitRange(base) {
            guard let a = value(dash.0, names), let b = value(dash.1, names) else { return nil }
            lo = a; hi = b
        } else {
            guard let v = value(base, names) else { return nil }
            if step == 1 {
                return (v >= min && v <= max) ? [v] : nil
            }
            lo = v; hi = max
        }
        guard lo >= min, hi <= max, lo <= hi else { return nil }
        var set = Set<Int>()
        var x = lo
        while x <= hi { set.insert(x); x += step }
        return set
    }

    private static func splitRange(_ s: String) -> (String, String)? {
        let parts = s.split(separator: "-", maxSplits: 1).map(String.init)
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }

    private static func value(_ s: String, _ names: [String: Int]) -> Int? {
        Int(s) ?? names[s.uppercased()]
    }

    private static func macroExpansion(_ s: String) -> String? {
        switch s.lowercased() {
        case "@yearly", "@annually": return "0 0 1 1 *"
        case "@monthly": return "0 0 1 * *"
        case "@weekly": return "0 0 * * 0"
        case "@daily", "@midnight": return "0 0 * * *"
        case "@hourly": return "0 * * * *"
        default: return nil
        }
    }

    private static func fieldError(_ name: String, _ value: String) -> Result<CronExpression, ToolError> {
        .failure(.parseFailure(reason: "Invalid \(name) field: \"\(value)\".",
                               hint: "Allowed: *, a value, a-b range, comma lists, and */step."))
    }

    private static func list(_ s: Set<Int>) -> String { s.sorted().map(String.init).joined(separator: ", ") }
    private static func dayName(_ d: Int) -> String { ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d] }
    private static func monthName(_ m: Int) -> String {
        ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][m]
    }
}
