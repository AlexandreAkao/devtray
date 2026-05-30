import CryptoKit
@testable import DevTrayCore
import XCTest

final class MachineIdentifierTests: XCTestCase {
    func test_hash_isStableForSameInputs() throws {
        let licenseUUID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let provider = StubMachineIDProvider(rawUUID: "AAAA-BBBB-CCCC")
        let a = try MachineIdentifier.hash(for: licenseUUID, provider: provider)
        let b = try MachineIdentifier.hash(for: licenseUUID, provider: provider)
        XCTAssertEqual(a, b)
    }

    func test_hash_differsForDifferentLicenseUUIDs() throws {
        let provider = StubMachineIDProvider(rawUUID: "AAAA-BBBB-CCCC")
        let a = try MachineIdentifier.hash(for: UUID(), provider: provider)
        let b = try MachineIdentifier.hash(for: UUID(), provider: provider)
        XCTAssertNotEqual(a, b)
    }

    func test_hash_differsForDifferentRawUUIDs() throws {
        let licenseUUID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let p1 = StubMachineIDProvider(rawUUID: "AAAA-BBBB-CCCC")
        let p2 = StubMachineIDProvider(rawUUID: "AAAA-BBBB-DDDD")
        let a = try MachineIdentifier.hash(for: licenseUUID, provider: p1)
        let b = try MachineIdentifier.hash(for: licenseUUID, provider: p2)
        XCTAssertNotEqual(a, b)
    }

    func test_hash_isLowercaseHex64Chars() throws {
        let licenseUUID = UUID()
        let provider = StubMachineIDProvider(rawUUID: "RAW")
        let h = try MachineIdentifier.hash(for: licenseUUID, provider: provider)
        XCTAssertEqual(h.count, 64)
        XCTAssertEqual(h, h.lowercased())
        XCTAssertNil(h.range(of: "[^0-9a-f]", options: .regularExpression))
    }

    func test_hash_includesSaltPrefix() throws {
        // The hash must equal SHA256("v1:" + licenseUUID.uuidString + ":" + rawUUID).
        let licenseUUID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let raw = "MY-MAC"
        let provider = StubMachineIDProvider(rawUUID: raw)
        let expectedInput = "v1:\(licenseUUID.uuidString):\(raw)"
        let expectedDigest = SHA256.hash(data: Data(expectedInput.utf8))
        let expected = expectedDigest.map { String(format: "%02x", $0) }.joined()
        let actual = try MachineIdentifier.hash(for: licenseUUID, provider: provider)
        XCTAssertEqual(actual, expected)
    }

    func test_raw_throwsWhenProviderUnavailable() {
        let provider = StubMachineIDProvider(rawUUID: nil)
        XCTAssertThrowsError(try MachineIdentifier.hash(for: UUID(), provider: provider)) { error in
            XCTAssertEqual(error as? MachineIdentifierError, .unavailable)
        }
    }
}

private struct StubMachineIDProvider: MachineIDProvider {
    let rawUUID: String?
    func read() throws -> String {
        guard let v = rawUUID else { throw MachineIdentifierError.unavailable }
        return v
    }
}
