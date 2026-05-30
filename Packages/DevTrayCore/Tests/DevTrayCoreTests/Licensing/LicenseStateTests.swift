@testable import DevTrayCore
import XCTest

final class LicenseStateTests: XCTestCase {
    func test_isGated_untrialed_returnsFalse() {
        XCTAssertFalse(LicenseState.untrialed.isGated)
    }

    func test_isGated_trialing_returnsFalse() {
        XCTAssertFalse(LicenseState.trialing(daysLeft: 7).isGated)
        XCTAssertFalse(LicenseState.trialing(daysLeft: 0).isGated)
    }

    func test_isGated_licensed_returnsFalse() {
        let claims = LicenseClaims.fixture()
        XCTAssertFalse(LicenseState.licensed(claims: claims).isGated)
    }

    func test_isGated_trialExpired_returnsTrue() {
        XCTAssertTrue(LicenseState.trialExpired.isGated)
    }

    func test_isGated_revoked_returnsTrue() {
        XCTAssertTrue(LicenseState.revoked.isGated)
    }

    func test_equatable_distinctCases() {
        XCTAssertNotEqual(LicenseState.trialing(daysLeft: 7), .trialing(daysLeft: 8))
        XCTAssertEqual(LicenseState.trialExpired, .trialExpired)
    }
}

/// Fixture lives here for now; later moved alongside LicenseClaims.
extension LicenseClaims {
    static func fixture(
        licenseUUID: UUID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        email: String = "buyer@example.com",
        issuedAt: Date = Date(timeIntervalSince1970: 1_748_560_000),
        tier: String = "v1"
    ) -> LicenseClaims {
        LicenseClaims(licenseUUID: licenseUUID, email: email, issuedAt: issuedAt, tier: tier)
    }
}
