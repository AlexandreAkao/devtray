import XCTest
@testable import DevTrayCore

final class AppMetadataTests: XCTestCase {
    func test_version_returnsNonEmptyString() {
        let v = AppMetadata.version
        XCTAssertFalse(v.isEmpty, "AppMetadata.version must not be empty")
    }
}
