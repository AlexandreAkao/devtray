import DevTrayCore
import Foundation

public enum JSONEngine {
    public static func format(_ raw: String) -> Result<String, ToolError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.invalidInput(reason: "JSON input is empty"))
        }
        guard let data = trimmed.data(using: .utf8) else {
            return .failure(.invalidInput(reason: "Input is not UTF-8"))
        }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let pretty = try JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
            )
            return .success(String(data: pretty, encoding: .utf8) ?? "")
        } catch {
            return .failure(.parseFailure(reason: "Invalid JSON", hint: error.localizedDescription))
        }
    }

    public static func minify(_ raw: String) -> Result<String, ToolError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.invalidInput(reason: "JSON input is empty"))
        }
        guard let data = trimmed.data(using: .utf8) else {
            return .failure(.invalidInput(reason: "Input is not UTF-8"))
        }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let mini = try JSONSerialization.data(
                withJSONObject: object,
                options: [.fragmentsAllowed]
            )
            return .success(String(data: mini, encoding: .utf8) ?? "")
        } catch {
            return .failure(.parseFailure(reason: "Invalid JSON", hint: error.localizedDescription))
        }
    }

    public static func isValid(_ raw: String) -> Bool {
        guard let data = raw.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
    }
}
