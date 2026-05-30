@testable import DevTrayCore
import XCTest

final class LicenseClientTests: XCTestCase {
    private var client: LicenseClient!
    private let licenseUUID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    private let licenseJWT = "DT1-fake.test.signature"
    private let machineHash = "abc123"

    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)
        client = LicenseClient(baseURL: URL(string: "https://api.devtray.app")!, session: session)
    }

    func test_activate_happyPath_returnsActivationResponse() async throws {
        URLProtocolStub.responder = { _ in
            let body = #"{"ok":true,"activations_remaining":2}"#
            return (HTTPURLResponse(statusCode: 200), Data(body.utf8))
        }
        let resp = try await client.activate(licenseJWT: licenseJWT, machineHash: machineHash)
        XCTAssertTrue(resp.ok)
        XCTAssertEqual(resp.activationsRemaining, 2)
    }

    func test_activate_tooMany_throws() async {
        URLProtocolStub.responder = { _ in
            let body = #"{"error":"too_many_activations"}"#
            return (HTTPURLResponse(statusCode: 403), Data(body.utf8))
        }
        do {
            _ = try await client.activate(licenseJWT: licenseJWT, machineHash: machineHash)
            XCTFail("expected throw")
        } catch let LicenseClientError.activationFailed(reason) {
            XCTAssertEqual(reason, "too_many_activations")
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func test_activate_404_throwsLicenseNotFound() async {
        URLProtocolStub.responder = { _ in (HTTPURLResponse(statusCode: 404), Data()) }
        do {
            _ = try await client.activate(licenseJWT: licenseJWT, machineHash: machineHash)
            XCTFail()
        } catch LicenseClientError.licenseNotFound {
            // expected
        } catch {
            XCTFail("wrong: \(error)")
        }
    }

    func test_deactivate_happyPath_returns() async throws {
        URLProtocolStub.responder = { _ in
            (HTTPURLResponse(statusCode: 200), Data(#"{"ok":true}"#.utf8))
        }
        try await client.deactivate(licenseJWT: licenseJWT, machineHash: machineHash)
    }

    func test_heartbeat_revokedTrue() async {
        URLProtocolStub.responder = { _ in
            (HTTPURLResponse(statusCode: 200), Data(#"{"revoked":true}"#.utf8))
        }
        let resp = await client.heartbeat(licenseUUID: licenseUUID, machineHash: machineHash)
        XCTAssertTrue(resp.revoked)
    }

    func test_heartbeat_revokedFalse() async {
        URLProtocolStub.responder = { _ in
            (HTTPURLResponse(statusCode: 200), Data(#"{"revoked":false}"#.utf8))
        }
        let resp = await client.heartbeat(licenseUUID: licenseUUID, machineHash: machineHash)
        XCTAssertFalse(resp.revoked)
    }

    func test_heartbeat_networkError_swallowsAndReturnsRevokedFalse() async {
        URLProtocolStub.responder = { _ in
            throw URLError(.notConnectedToInternet)
        }
        let resp = await client.heartbeat(licenseUUID: licenseUUID, machineHash: machineHash)
        XCTAssertFalse(resp.revoked)
    }

    func test_heartbeat_serverError_swallowsAndReturnsRevokedFalse() async {
        URLProtocolStub.responder = { _ in (HTTPURLResponse(statusCode: 500), Data()) }
        let resp = await client.heartbeat(licenseUUID: licenseUUID, machineHash: machineHash)
        XCTAssertFalse(resp.revoked)
    }

    func test_activate_postsExpectedBody() async throws {
        var capturedBody: Data?
        URLProtocolStub.responder = { req in
            capturedBody = req.httpBodyOrBodyStream()
            return (HTTPURLResponse(statusCode: 200), Data(#"{"ok":true,"activations_remaining":1}"#.utf8))
        }
        _ = try await client.activate(licenseJWT: licenseJWT, machineHash: "xyz")
        let json = try XCTUnwrap(capturedBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        XCTAssertEqual(json["machine_hash"] as? String, "xyz")
        XCTAssertEqual(json["license_jwt"] as? String, licenseJWT)
    }
}

// MARK: - URLProtocol stub

private final class URLProtocolStub: URLProtocol {
    typealias Response = (HTTPURLResponse, Data)
    static var responder: (@Sendable (URLRequest) throws -> Response)?
    static func reset() { responder = nil }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let responder = URLProtocolStub.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (resp, data) = try responder(request)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension HTTPURLResponse {
    convenience init(statusCode: Int) {
        self.init(url: URL(string: "https://api.devtray.app")!,
                  statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
    }
}

private extension URLRequest {
    /// URLProtocol seems to receive the body via httpBodyStream when using URLSession.upload-style flows;
    /// for the simple POST we set explicitly via httpBody.
    func httpBodyOrBodyStream() -> Data? {
        if let b = httpBody { return b }
        guard let stream = httpBodyStream else { return nil }
        stream.open(); defer { stream.close() }
        var data = Data(); let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buf.deallocate() }
        while stream.hasBytesAvailable {
            let n = stream.read(buf, maxLength: 4096)
            if n <= 0 { break }
            data.append(buf, count: n)
        }
        return data
    }
}
