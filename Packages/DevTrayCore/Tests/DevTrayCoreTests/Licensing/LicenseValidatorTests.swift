import CryptoKit
@testable import DevTrayCore
import XCTest

final class LicenseValidatorTests: XCTestCase {
    private var privateKey: Curve25519.Signing.PrivateKey!
    private var publicKey: Curve25519.Signing.PublicKey!
    private var validator: LicenseValidator!

    override func setUp() {
        super.setUp()
        privateKey = Curve25519.Signing.PrivateKey()
        publicKey = privateKey.publicKey
        validator = LicenseValidator(publicKey: publicKey)
    }

    private func makeToken(
        alg: String = "EdDSA",
        typ: String = "JWT",
        payload: [String: Any] = [
            "iss": "api.devtray.app",
            "sub": "11111111-1111-1111-1111-111111111111",
            "email": "buyer@example.com",
            "iat": 1_748_560_000,
            "tier": "v1",
        ],
        signWith key: Curve25519.Signing.PrivateKey? = nil,
        prefix: String = "DT1-"
    ) throws -> String {
        let header: [String: Any] = ["alg": alg, "typ": typ]
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        let headerB64 = headerData.base64URLEncodedString()
        let payloadB64 = payloadData.base64URLEncodedString()
        let signingInput = "\(headerB64).\(payloadB64)"
        let signature = try (key ?? privateKey).signature(for: Data(signingInput.utf8))
        let sigB64 = signature.base64URLEncodedString()
        return "\(prefix)\(headerB64).\(payloadB64).\(sigB64)"
    }

    func test_verify_happyPath_returnsClaims() throws {
        let token = try makeToken()
        let claims = try validator.verify(token)
        XCTAssertEqual(claims.licenseUUID, UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        XCTAssertEqual(claims.email, "buyer@example.com")
        XCTAssertEqual(claims.tier, "v1")
        XCTAssertEqual(claims.issuedAt, Date(timeIntervalSince1970: 1_748_560_000))
    }

    func test_verify_missingPrefix_throws() throws {
        let token = try makeToken(prefix: "")
        XCTAssertThrowsError(try validator.verify(token)) { err in
            XCTAssertEqual(err as? LicenseValidationError, .unsupportedSchema)
        }
    }

    func test_verify_wrongPrefix_throws() throws {
        let token = try makeToken(prefix: "DT2-")
        XCTAssertThrowsError(try validator.verify(token)) { err in
            XCTAssertEqual(err as? LicenseValidationError, .unsupportedSchema)
        }
    }

    func test_verify_malformedToken_notThreeSegments_throws() {
        XCTAssertThrowsError(try validator.verify("DT1-only.two")) { err in
            XCTAssertEqual(err as? LicenseValidationError, .malformedToken)
        }
    }

    func test_verify_algNone_throws() throws {
        let token = try makeToken(alg: "none")
        XCTAssertThrowsError(try validator.verify(token)) { err in
            XCTAssertEqual(err as? LicenseValidationError, .invalidAlgorithm)
        }
    }

    func test_verify_wrongTyp_throws() throws {
        let token = try makeToken(typ: "OTHER")
        XCTAssertThrowsError(try validator.verify(token)) { err in
            XCTAssertEqual(err as? LicenseValidationError, .invalidAlgorithm)
        }
    }

    func test_verify_signedByDifferentKey_throws() throws {
        let otherKey = Curve25519.Signing.PrivateKey()
        let token = try makeToken(signWith: otherKey)
        XCTAssertThrowsError(try validator.verify(token)) { err in
            XCTAssertEqual(err as? LicenseValidationError, .invalidSignature)
        }
    }

    func test_verify_wrongTier_throws() throws {
        let payload: [String: Any] = [
            "iss": "api.devtray.app",
            "sub": "11111111-1111-1111-1111-111111111111",
            "email": "buyer@example.com",
            "iat": 1_748_560_000,
            "tier": "v2",
        ]
        let token = try makeToken(payload: payload)
        XCTAssertThrowsError(try validator.verify(token)) { err in
            XCTAssertEqual(err as? LicenseValidationError, .unsupportedTier)
        }
    }

    func test_verify_malformedSignatureEncoding_throwsInvalidSignature() throws {
        // Build a real token, then replace the sig segment with non-base64url garbage.
        let realToken = try makeToken()
        let body = String(realToken.dropFirst("DT1-".count))
        let parts = body.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        XCTAssertEqual(parts.count, 3)
        let garbage = "!!!not-base64-at-all!!!"
        let tampered = "DT1-\(parts[0]).\(parts[1]).\(garbage)"
        XCTAssertThrowsError(try validator.verify(tampered)) { err in
            XCTAssertEqual(err as? LicenseValidationError, .invalidSignature)
        }
    }
}
