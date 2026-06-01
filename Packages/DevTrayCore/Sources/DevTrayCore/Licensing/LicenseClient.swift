import Combine
import Foundation

public struct ActivationResponse: Codable, Sendable, Equatable {
    public let ok: Bool
    public let activationsRemaining: Int
}

public struct HeartbeatResponse: Codable, Sendable, Equatable {
    public let revoked: Bool
}

public enum LicenseClientError: Error, Equatable {
    case activationFailed(reason: String) // 403 with {"error":"..."}
    case licenseNotFound // 404
    case unexpectedStatus(Int)
    case malformedResponse
    case transport // generic for activate/deactivate
}

public actor LicenseClient: ObservableObject {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let activationTimeout: TimeInterval = 10
    private let heartbeatTimeout: TimeInterval = 3

    public init(baseURL: URL = URL(string: "https://api.devtray.app")!,
                session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        let dec = JSONDecoder(); dec.keyDecodingStrategy = .convertFromSnakeCase
        let enc = JSONEncoder(); enc.keyEncodingStrategy = .convertToSnakeCase
        self.decoder = dec
        self.encoder = enc
    }

    /// Posts the full JWT (not just the UUID) so the backend can re-verify the signature
    /// server-side — anti-fraud guard against arbitrary UUID claims.
    public func activate(licenseJWT: String, machineHash: String) async throws -> ActivationResponse {
        let req = try makePOST(path: "/activate",
                               body: ActivateRequest(licenseJwt: licenseJWT, machineHash: machineHash),
                               timeout: activationTimeout)
        let (data, resp) = try await sendOrTransport(req)
        let http = resp as! HTTPURLResponse
        switch http.statusCode {
        case 200:
            guard let r = try? decoder.decode(ActivationResponse.self, from: data) else {
                throw LicenseClientError.malformedResponse
            }
            return r
        case 403:
            let payload = (try? decoder.decode(ErrorEnvelope.self, from: data))?.error ?? "forbidden"
            throw LicenseClientError.activationFailed(reason: payload)
        case 404:
            throw LicenseClientError.licenseNotFound
        default:
            throw LicenseClientError.unexpectedStatus(http.statusCode)
        }
    }

    public func deactivate(licenseJWT: String, machineHash: String) async throws {
        let req = try makePOST(path: "/deactivate",
                               body: ActivateRequest(licenseJwt: licenseJWT, machineHash: machineHash),
                               timeout: activationTimeout)
        let (_, resp) = try await sendOrTransport(req)
        let http = resp as! HTTPURLResponse
        switch http.statusCode {
        case 200: return
        case 404: throw LicenseClientError.licenseNotFound
        default: throw LicenseClientError.unexpectedStatus(http.statusCode)
        }
    }

    /// Heartbeat is best-effort: any failure (network, server, decode) returns `revoked:false`.
    /// The app NEVER flips state on a heartbeat failure — only on an explicit `revoked:true` response.
    public func heartbeat(licenseUUID: UUID, machineHash: String) async -> HeartbeatResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("status"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "license", value: licenseUUID.uuidString),
            URLQueryItem(name: "machine", value: machineHash),
        ]
        guard let url = components.url else { return HeartbeatResponse(revoked: false) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = heartbeatTimeout
        do {
            let (data, resp) = try await session.data(for: req)
            let http = resp as! HTTPURLResponse
            guard http.statusCode == 200 else { return HeartbeatResponse(revoked: false) }
            guard let r = try? decoder.decode(HeartbeatResponse.self, from: data) else {
                return HeartbeatResponse(revoked: false)
            }
            return r
        } catch {
            return HeartbeatResponse(revoked: false)
        }
    }

    // MARK: - Private

    private struct ActivateRequest: Codable {
        let licenseJwt: String // snake_case encoder produces "license_jwt" on the wire
        let machineHash: String
    }

    private struct ErrorEnvelope: Codable {
        let error: String?
    }

    private func makePOST(path: String, body: some Encodable, timeout: TimeInterval) throws -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        req.timeoutInterval = timeout
        return req
    }

    private func sendOrTransport(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do { return try await session.data(for: req) }
        catch { throw LicenseClientError.transport }
    }
}
