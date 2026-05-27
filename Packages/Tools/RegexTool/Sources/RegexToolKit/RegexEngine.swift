import Foundation
import DevTrayCore

public struct RegexFlags: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let caseInsensitive = RegexFlags(rawValue: 1 << 0)
    public static let multiline = RegexFlags(rawValue: 1 << 1)
    public static let dotMatchesLineSeparators = RegexFlags(rawValue: 1 << 2)

    var nsOptions: NSRegularExpression.Options {
        var o: NSRegularExpression.Options = []
        if contains(.caseInsensitive) { o.insert(.caseInsensitive) }
        if contains(.multiline) { o.insert(.anchorsMatchLines) }
        if contains(.dotMatchesLineSeparators) { o.insert(.dotMatchesLineSeparators) }
        return o
    }
}

public struct RegexGroup: Equatable, Sendable {
    public let index: Int
    public let name: String?       // reserved; always nil in v0.7 (numbered groups only)
    public let value: String?      // nil when the group did not participate
    public init(index: Int, name: String?, value: String?) {
        self.index = index; self.name = name; self.value = value
    }
}

public struct RegexMatch: Equatable, Sendable {
    public let value: String
    public let groups: [RegexGroup]
    public init(value: String, groups: [RegexGroup]) {
        self.value = value; self.groups = groups
    }
}

public enum RegexEngine {
    public static func evaluate(pattern: String, flags: RegexFlags, input: String) -> Result<[RegexMatch], ToolError> {
        guard !pattern.isEmpty else { return .success([]) }
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: flags.nsOptions)
        } catch {
            return .failure(.parseFailure(reason: error.localizedDescription, hint: nil))
        }
        let ns = input as NSString
        let full = NSRange(location: 0, length: ns.length)
        var results: [RegexMatch] = []
        regex.enumerateMatches(in: input, options: [], range: full) { result, _, _ in
            guard let result else { return }
            var groups: [RegexGroup] = []
            for i in 0..<result.numberOfRanges {
                let nsr = result.range(at: i)
                if nsr.location == NSNotFound {
                    groups.append(RegexGroup(index: i, name: nil, value: nil))
                } else {
                    groups.append(RegexGroup(index: i, name: nil, value: ns.substring(with: nsr)))
                }
            }
            results.append(RegexMatch(value: ns.substring(with: result.range), groups: groups))
        }
        return .success(results)
    }

    public static func replace(pattern: String, flags: RegexFlags, input: String, template: String) -> Result<String, ToolError> {
        guard !pattern.isEmpty else { return .success(input) }
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: flags.nsOptions)
        } catch {
            return .failure(.parseFailure(reason: error.localizedDescription, hint: nil))
        }
        let ns = input as NSString
        let full = NSRange(location: 0, length: ns.length)
        return .success(regex.stringByReplacingMatches(in: input, options: [], range: full, withTemplate: template))
    }
}
