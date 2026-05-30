import Foundation

public actor LicenseStore {
    public struct Stored: Equatable, Sendable {
        public let jwt: String
        public let claims: LicenseClaims
        public let machineHash: String
        public let activatedAt: Date
    }

    private let keychain: KeychainProtocol
    private let clock: @Sendable () -> Date
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(keychain: KeychainProtocol = SystemKeychain(),
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.keychain = keychain
        self.clock = clock
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .secondsSince1970
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .secondsSince1970
    }

    public func storeLicense(_ jwt: String, claims: LicenseClaims, machineHash: String) throws {
        try keychain.set(Data(jwt.utf8), account: Account.licenseJWT)
        try keychain.set(try encoder.encode(claims), account: Account.claims)
        try keychain.set(Data(machineHash.utf8), account: Account.machineHash)
        try keychain.set(try encoder.encode(clock()), account: Account.activatedAt)
    }

    public func storedLicense() throws -> Stored? {
        guard let jwtData = try keychain.get(account: Account.licenseJWT),
              let jwt = String(data: jwtData, encoding: .utf8),
              let claimsData = try keychain.get(account: Account.claims),
              let claims = try? decoder.decode(LicenseClaims.self, from: claimsData),
              let machineHashData = try keychain.get(account: Account.machineHash),
              let machineHash = String(data: machineHashData, encoding: .utf8),
              let activatedData = try keychain.get(account: Account.activatedAt),
              let activatedAt = try? decoder.decode(Date.self, from: activatedData)
        else { return nil }
        return Stored(jwt: jwt, claims: claims, machineHash: machineHash, activatedAt: activatedAt)
    }

    public func clearLicense() throws {
        try keychain.delete(account: Account.licenseJWT)
        try keychain.delete(account: Account.claims)
        try keychain.delete(account: Account.machineHash)
        try keychain.delete(account: Account.activatedAt)
    }

    private enum Account {
        static let licenseJWT = "license_jwt"
        static let claims = "license_claims_json"
        static let machineHash = "machine_hash"
        static let activatedAt = "activated_at"
    }
}
