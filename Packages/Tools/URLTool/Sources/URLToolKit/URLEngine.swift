import DevTrayCore
import Foundation

public enum URLEngine {
    public static func encode(_ raw: String) -> Result<String, ToolError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.invalidInput(reason: "Input is empty"))
        }
        // Use the original (untrimmed) input for encoding so the user's
        // exact bytes are preserved if they intentionally included spaces.
        guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return .failure(.parseFailure(reason: "Could not percent-encode input", hint: nil))
        }
        return .success(encoded)
    }

    public static func decode(_ raw: String) -> Result<String, ToolError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.invalidInput(reason: "Input is empty"))
        }
        guard let decoded = raw.removingPercentEncoding else {
            return .failure(.parseFailure(reason: "Invalid percent-encoding", hint: nil))
        }
        return .success(decoded)
    }
}
