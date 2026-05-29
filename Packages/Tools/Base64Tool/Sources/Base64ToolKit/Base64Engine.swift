import Foundation
import DevTrayCore

public enum Base64Engine {
    public static func encode(_ raw: String) -> Result<String, ToolError> {
        guard !raw.isEmpty else {
            return .failure(.invalidInput(reason: "Input is empty"))
        }
        guard let data = raw.data(using: .utf8) else {
            return .failure(.invalidInput(reason: "Input is not valid UTF-8"))
        }
        return .success(data.base64EncodedString())
    }

    public static func encode(_ data: Data) -> String {
        data.base64EncodedString()
    }

    public static func decode(_ raw: String) -> Result<String, ToolError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.invalidInput(reason: "Input is empty"))
        }
        var padded = trimmed
        let mod = padded.count % 4
        if mod != 0 {
            padded.append(String(repeating: "=", count: 4 - mod))
        }
        guard let data = Data(base64Encoded: padded, options: [.ignoreUnknownCharacters]),
              !data.isEmpty || trimmed.allSatisfy({ $0 == "=" }) else {
            return .failure(.parseFailure(reason: "Not valid base64", hint: nil))
        }
        guard let string = String(data: data, encoding: .utf8) else {
            return .failure(.parseFailure(
                reason: "Decoded bytes are not valid UTF-8",
                hint: nil
            ))
        }
        return .success(string)
    }
}
