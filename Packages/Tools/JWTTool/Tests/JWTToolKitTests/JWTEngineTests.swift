import XCTest
@testable import JWTToolKit

final class JWTEngineTests: XCTestCase {
    private let validJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

    func test_decode_validJWT_returnsDecoded() throws {
        let result = JWTEngine.decode(validJWT)
        guard case .success(let decoded) = result else {
            XCTFail("expected success, got \(result)"); return
        }
        XCTAssertEqual(decoded.algorithm, "HS256")
        XCTAssertTrue(decoded.headerJSON.contains("\"alg\""))
        XCTAssertTrue(decoded.payloadJSON.contains("\"sub\""))
        XCTAssertEqual(decoded.signature, "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c")
    }

    func test_decode_missingSegments_returnsParseFailure() {
        let result = JWTEngine.decode("not-a-jwt")
        guard case .failure(.parseFailure(let reason, _)) = result else {
            XCTFail("expected parseFailure"); return
        }
        XCTAssertTrue(reason.contains("3 parts"))
    }

    func test_decode_invalidBase64_returnsParseFailure() {
        let result = JWTEngine.decode("!!!.!!!.!!!")
        if case .failure(.parseFailure) = result { return }
        XCTFail("expected parseFailure for invalid base64")
    }

    func test_decode_headerNotJSON_returnsParseFailure() {
        let badHeader = Data("not json".utf8).base64URLEncoded()
        let validPayload = Data("{}".utf8).base64URLEncoded()
        let result = JWTEngine.decode("\(badHeader).\(validPayload).sig")
        if case .failure(.parseFailure) = result { return }
        XCTFail("expected parseFailure for non-JSON header")
    }

    func test_decode_emptyInput_returnsInvalidInput() {
        let result = JWTEngine.decode("")
        if case .failure(.invalidInput) = result { return }
        XCTFail("expected invalidInput for empty string")
    }
}

private extension Data {
    func base64URLEncoded() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
