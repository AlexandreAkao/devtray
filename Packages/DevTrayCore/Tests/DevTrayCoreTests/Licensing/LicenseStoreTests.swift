import XCTest
@testable import DevTrayCore

final class LicenseStoreTests: XCTestCase {
    private var kc: InMemoryKeychain!
    private var store: LicenseStore!
    private let claims = LicenseClaims.fixture()
    private let jwt = "DT1-header.payload.signature"
    private let machineHash = "deadbeef"

    override func setUp() async throws {
        kc = InMemoryKeychain()
        store = LicenseStore(keychain: kc)
    }

    func test_storeLicense_thenStoredLicense_roundtrips() async throws {
        try await store.storeLicense(jwt, claims: claims, machineHash: machineHash)
        let stored = try await store.storedLicense()
        XCTAssertEqual(stored?.jwt, jwt)
        XCTAssertEqual(stored?.claims, claims)
        XCTAssertEqual(stored?.machineHash, machineHash)
        XCTAssertNotNil(stored?.activatedAt)
    }

    func test_storedLicense_whenEmpty_returnsNil() async throws {
        let stored = try await store.storedLicense()
        XCTAssertNil(stored)
    }

    func test_clearLicense_removesAllItems() async throws {
        try await store.storeLicense(jwt, claims: claims, machineHash: machineHash)
        try await store.clearLicense()
        let stored = try await store.storedLicense()
        XCTAssertNil(stored)
    }

    func test_storedLicense_partialData_returnsNil() async throws {
        // Simulate corruption: write only the JWT, no claims JSON.
        try kc.set(Data(jwt.utf8), account: "license_jwt")
        let stored = try await store.storedLicense()
        XCTAssertNil(stored)
    }

    func test_storeLicense_overwritesPrevious() async throws {
        try await store.storeLicense(jwt, claims: claims, machineHash: machineHash)
        let newClaims = LicenseClaims.fixture(email: "other@example.com")
        try await store.storeLicense("DT1-new.token.sig", claims: newClaims, machineHash: "newhash")
        let stored = try await store.storedLicense()
        XCTAssertEqual(stored?.jwt, "DT1-new.token.sig")
        XCTAssertEqual(stored?.claims.email, "other@example.com")
        XCTAssertEqual(stored?.machineHash, "newhash")
    }
}
