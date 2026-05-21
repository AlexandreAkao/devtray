import Foundation
import DevTrayCore

public enum JWTEngine {
    public static func decode(_ raw: String) -> Result<DecodedJWT, ToolError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.invalidInput(reason: "JWT input is empty"))
        }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            return .failure(.parseFailure(
                reason: "JWT must have 3 parts separated by '.'",
                hint: "got \(parts.count) part(s)"
            ))
        }

        guard let headerData = Base64URL.decode(String(parts[0])),
              let payloadData = Base64URL.decode(String(parts[1])) else {
            return .failure(.parseFailure(
                reason: "Header or payload is not valid base64url",
                hint: nil
            ))
        }

        guard let headerObj = try? JSONSerialization.jsonObject(with: headerData),
              let payloadObj = try? JSONSerialization.jsonObject(with: payloadData) else {
            return .failure(.parseFailure(
                reason: "Header or payload is not valid JSON",
                hint: nil
            ))
        }

        let headerJSON = prettyPrint(headerObj) ?? ""
        let payloadJSON = prettyPrint(payloadObj) ?? ""
        let algorithm = (headerObj as? [String: Any])?["alg"] as? String

        return .success(DecodedJWT(
            headerJSON: headerJSON,
            payloadJSON: payloadJSON,
            signature: String(parts[2]),
            algorithm: algorithm
        ))
    }

    private static func prettyPrint(_ object: Any) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
