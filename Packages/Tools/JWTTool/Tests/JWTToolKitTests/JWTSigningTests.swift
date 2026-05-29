import XCTest
@testable import JWTToolKit
import DevTrayCore

final class JWTSigningTests: XCTestCase {
    // Known HS256 token (jwt.io example), secret "your-256-bit-secret".
    let hsToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    let hsSecret = "your-256-bit-secret"

    func test_hs256_verify_validSecret() {
        let r = JWTEngine.verify(token: hsToken, algorithm: .hs256, key: hsSecret)
        XCTAssertEqual(try? r.get(), true)
    }
    func test_hs256_verify_wrongSecret() {
        let r = JWTEngine.verify(token: hsToken, algorithm: .hs256, key: "wrong")
        XCTAssertEqual(try? r.get(), false)
    }
    func test_hs256_encode_then_verify_roundTrip() {
        let header = #"{"alg":"HS256","typ":"JWT"}"#
        let claims = #"{"sub":"42","name":"Ada"}"#
        guard case .success(let token) = JWTEngine.encode(
            headerJSON: header, claimsJSON: claims, algorithm: .hs256, key: "k") else {
            return XCTFail("encode failed")
        }
        XCTAssertEqual(token.split(separator: ".").count, 3)
        XCTAssertEqual(try? JWTEngine.verify(token: token, algorithm: .hs256, key: "k").get(), true)
        XCTAssertEqual(try? JWTEngine.verify(token: token, algorithm: .hs256, key: "x").get(), false)
        // Encode pipeline produces a decodable token with the expected (sorted) claims.
        guard case .success(let back) = JWTEngine.decode(token) else { return XCTFail("decode failed") }
        XCTAssertTrue(back.payloadJSON.contains("\"sub\" : \"42\""))
        XCTAssertTrue(back.payloadJSON.contains("\"name\" : \"Ada\""))
    }
    func test_encode_invalidClaimsJSON_fails() {
        if case .success = JWTEngine.encode(
            headerJSON: "{}", claimsJSON: "not json", algorithm: .hs256, key: "k") {
            XCTFail("expected failure on invalid claims JSON")
        }
    }
}
