import XCTest
@testable import DevTrayCore

final class AppMetadataTests: XCTestCase {
    func test_version_returnsNonEmptyString() {
        let v = AppMetadata.version
        XCTAssertFalse(v.isEmpty, "AppMetadata.version must not be empty")
    }

    func test_version_returnsQuestionMark_whenBundleHasNoVersionKey() {
        // In the swift-test runner Bundle.main has no CFBundleShortVersionString,
        // so the helper must fall back to "?".
        XCTAssertEqual(AppMetadata.version, "?")
    }
}
