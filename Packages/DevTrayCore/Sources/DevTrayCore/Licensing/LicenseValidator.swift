import CryptoKit
import Foundation

public enum LicenseValidationError: Error, Equatable {
    case unsupportedSchema // missing DT1- prefix or wrong prefix
    case malformedToken // not exactly 3 dot-separated segments
    case invalidAlgorithm // alg != EdDSA or typ != JWT
    case invalidSignature // EdDSA verify failed
    case malformedPayload // JSON decode failed
    case unsupportedTier // tier != "v1"
    case publicKeyMissing // Info.plist LICENSE_PUBLIC_KEY missing / unparseable
}

/// Verifies DT1-prefixed Ed25519-signed JWT licenses against an embedded pubkey.
public struct LicenseValidator: Sendable {
    private let publicKey: Curve25519.Signing.PublicKey
    private static let prefix = "DT1-"

    public init(publicKey: Curve25519.Signing.PublicKey) {
        self.publicKey = publicKey
    }

    /// Convenience: load pubkey from Info.plist `LICENSE_PUBLIC_KEY` (base64-encoded raw 32 bytes).
    public init(infoPlist: [String: Any] = Bundle.main.infoDictionary ?? [:]) throws {
        guard let b64 = infoPlist["LICENSE_PUBLIC_KEY"] as? String,
              let data = Data(base64Encoded: b64),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: data)
        else { throw LicenseValidationError.publicKeyMissing }
        self.publicKey = key
    }

    public func verify(_ rawKey: String) throws -> LicenseClaims {
        guard rawKey.hasPrefix(Self.prefix) else { throw LicenseValidationError.unsupportedSchema }
        let token = String(rawKey.dropFirst(Self.prefix.count))
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else { throw LicenseValidationError.malformedToken }

        let headerB64 = String(segments[0])
        let payloadB64 = String(segments[1])
        let sigB64 = String(segments[2])

        guard let headerData = Data(base64URLEncoded: headerB64),
              let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any]
        else { throw LicenseValidationError.malformedToken }

        guard (header["alg"] as? String) == "EdDSA",
              (header["typ"] as? String) == "JWT"
        else { throw LicenseValidationError.invalidAlgorithm }

        guard let sigData = Data(base64URLEncoded: sigB64) else {
            throw LicenseValidationError.invalidSignature
        }

        let signingInput = "\(headerB64).\(payloadB64)"
        guard publicKey.isValidSignature(sigData, for: Data(signingInput.utf8)) else {
            throw LicenseValidationError.invalidSignature
        }

        guard let payloadData = Data(base64URLEncoded: payloadB64),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let subStr = payload["sub"] as? String, let licenseUUID = UUID(uuidString: subStr),
              let email = payload["email"] as? String,
              let iat = payload["iat"] as? TimeInterval,
              let tier = payload["tier"] as? String
        else { throw LicenseValidationError.malformedPayload }

        guard tier == "v1" else { throw LicenseValidationError.unsupportedTier }

        return LicenseClaims(
            licenseUUID: licenseUUID,
            email: email,
            issuedAt: Date(timeIntervalSince1970: iat),
            tier: tier
        )
    }
}

// MARK: - base64url helpers

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded: String) {
        var s = base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = s.count % 4
        if pad > 0 { s.append(String(repeating: "=", count: 4 - pad)) }
        guard let d = Data(base64Encoded: s) else { return nil }
        self = d
    }
}
