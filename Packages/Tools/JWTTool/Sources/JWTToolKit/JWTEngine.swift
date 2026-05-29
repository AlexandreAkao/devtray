import CryptoKit
import DevTrayCore
import Foundation

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

    public enum JWTAlgorithm: String, CaseIterable, Sendable { case hs256 = "HS256", rs256 = "RS256" }

    public static func verify(token: String, algorithm: JWTAlgorithm, key: String) -> Result<Bool, ToolError> {
        let parts = token.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            return .failure(.parseFailure(reason: "JWT must have 3 parts", hint: "got \(parts.count)"))
        }
        let signingInput = "\(parts[0]).\(parts[1])"
        guard let providedSig = Base64URL.decode(String(parts[2])) else {
            return .failure(.parseFailure(reason: "Signature is not valid base64url", hint: nil))
        }
        switch algorithm {
        case .hs256:
            let mac = HMAC<SHA256>.authenticationCode(
                for: Data(signingInput.utf8), using: SymmetricKey(data: Data(key.utf8)))
            // Byte equality (not constant-time). Acceptable: local dev tool verifying a
            // user-supplied token; no remote timing side-channel.
            return .success(Data(mac) == providedSig)
        case .rs256:
            return RSAKey.verify(signingInput: Data(signingInput.utf8), signature: providedSig, pemPublicKey: key)
        }
    }

    public static func encode(headerJSON: String, claimsJSON: String, algorithm: JWTAlgorithm, key: String) -> Result<String, ToolError> {
        guard let headerData = minifiedJSON(headerJSON) else {
            return .failure(.invalidInput(reason: "Header is not valid JSON"))
        }
        guard let claimsData = minifiedJSON(claimsJSON) else {
            return .failure(.invalidInput(reason: "Claims are not valid JSON"))
        }
        let signingInput = "\(Base64URL.encode(headerData)).\(Base64URL.encode(claimsData))"
        switch algorithm {
        case .hs256:
            let mac = HMAC<SHA256>.authenticationCode(
                for: Data(signingInput.utf8), using: SymmetricKey(data: Data(key.utf8)))
            return .success("\(signingInput).\(Base64URL.encode(Data(mac)))")
        case .rs256:
            return RSAKey.sign(signingInput: Data(signingInput.utf8), pemPrivateKey: key)
                .map { "\(signingInput).\(Base64URL.encode($0))" }
        }
    }

    /// Validates + minifies JSON for signing. Uses `.sortedKeys`, so object keys are
    /// canonicalized alphabetically — the encoded payload's key order will not match the
    /// user's input order. Intentional: makes encoding deterministic. (Validity is unaffected;
    /// JWT does not depend on key order.)
    private static func minifiedJSON(_ s: String) -> Data? {
        guard let d = s.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: d),
              let out = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
        else { return nil }
        return out
    }
}
