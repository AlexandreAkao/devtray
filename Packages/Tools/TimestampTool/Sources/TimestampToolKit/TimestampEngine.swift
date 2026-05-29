import DevTrayCore
import Foundation

public enum TimestampEngine {
    public static func parse(_ raw: String) -> Result<TimestampBreakdown, ToolError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.invalidInput(reason: "Input is empty"))
        }

        // All-digit path (no sign, no separators)
        let isAllDigit = trimmed.allSatisfy { $0.isASCII && $0.isNumber }
        if isAllDigit {
            guard let n = Int64(trimmed) else {
                return .failure(.parseFailure(
                    reason: "Numeric value out of range",
                    hint: nil
                ))
            }
            switch trimmed.count {
            case 10:
                return .success(breakdown(seconds: n))
            case 13:
                return .success(breakdown(milliseconds: n))
            default:
                return .failure(.parseFailure(
                    reason: "Numeric timestamp must be 10 digits (seconds) or 13 digits (milliseconds)",
                    hint: nil
                ))
            }
        }

        // ISO 8601 path
        if let date = isoParse(trimmed, fractional: false)
            ?? isoParse(trimmed, fractional: true) {
            let ms = Int64((date.timeIntervalSince1970 * 1000).rounded())
            return .success(breakdown(milliseconds: ms))
        }

        return .failure(.parseFailure(
            reason: "Not a valid epoch or ISO 8601 timestamp",
            hint: nil
        ))
    }

    public static func now() -> TimestampBreakdown {
        let ms = Int64((Date().timeIntervalSince1970 * 1000).rounded())
        return breakdown(milliseconds: ms)
    }

    // MARK: - Helpers

    private static func breakdown(seconds: Int64) -> TimestampBreakdown {
        breakdown(milliseconds: seconds * 1000)
    }

    private static func breakdown(milliseconds: Int64) -> TimestampBreakdown {
        let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000.0)
        let utc = utcFormatter.string(from: date)
        let local = localFormatter.string(from: date)
        return TimestampBreakdown(
            epochSeconds: Int64((Double(milliseconds) / 1000.0).rounded(.down)),
            epochMillis: milliseconds,
            isoUTC: utc,
            isoLocal: local
        )
    }

    private static let utcFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let localFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone.current
        return f
    }()

    private static func isoParse(_ s: String, fractional: Bool) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = fractional
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return f.date(from: s)
    }
}
