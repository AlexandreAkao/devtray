import Foundation
import Security
import DevTrayCore

enum RSAKey {
    static func verify(signingInput: Data, signature: Data, pemPublicKey: String) -> Result<Bool, ToolError> {
        key(from: pemPublicKey, isPrivate: false).flatMap { key in
            var err: Unmanaged<CFError>?
            let ok = SecKeyVerifySignature(
                key, .rsaSignatureMessagePKCS1v15SHA256,
                signingInput as CFData, signature as CFData, &err)
            _ = err?.takeRetainedValue() // release the CFError SecFw retains on the false path
            return .success(ok)
        }
    }

    static func sign(signingInput: Data, pemPrivateKey: String) -> Result<Data, ToolError> {
        key(from: pemPrivateKey, isPrivate: true).flatMap { key in
            var err: Unmanaged<CFError>?
            guard let sig = SecKeyCreateSignature(
                key, .rsaSignatureMessagePKCS1v15SHA256, signingInput as CFData, &err) else {
                return .failure(.invalidInput(reason: cfError(err) ?? "RSA signing failed"))
            }
            return .success(sig as Data)
        }
    }

    /// Parses a PKCS#1 RSA PEM ("BEGIN RSA PUBLIC/PRIVATE KEY"). PKCS#8 / SPKI
    /// ("BEGIN PUBLIC/PRIVATE KEY") is not supported — error suggests conversion.
    private static func key(from pem: String, isPrivate: Bool) -> Result<SecKey, ToolError> {
        if pem.contains("BEGIN PUBLIC KEY") || pem.contains("BEGIN PRIVATE KEY") {
            let hint = isPrivate
                ? "`openssl rsa -in key.pem -out pkcs1.pem`"
                : "`openssl rsa -in key.pem -RSAPublicKey_out`"
            return .failure(.invalidInput(
                reason: "PKCS#8/SPKI key not supported — convert to PKCS#1: \(hint)"))
        }
        let body = pem
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("-----") }
            .map { $0.trimmingCharacters(in: .whitespaces) }  // strips \r and stray spaces per line
            .joined()
        guard !body.isEmpty, let der = Data(base64Encoded: body) else {
            return .failure(.invalidInput(reason: "Key is not valid PEM/base64"))
        }
        let attrs: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: isPrivate ? kSecAttrKeyClassPrivate : kSecAttrKeyClassPublic,
        ]
        var err: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(der as CFData, attrs as CFDictionary, &err) else {
            return .failure(.invalidInput(reason: cfError(err) ?? "Could not parse RSA key"))
        }
        return .success(key)
    }

    private static func cfError(_ err: Unmanaged<CFError>?) -> String? {
        guard let e = err?.takeRetainedValue() else { return nil }
        return CFErrorCopyDescription(e) as String?
    }
}
