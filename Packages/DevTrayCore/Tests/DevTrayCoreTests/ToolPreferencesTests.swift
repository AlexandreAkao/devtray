import XCTest
@testable import DevTrayCore

@MainActor
final class ToolPreferencesTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    func test_defaultAllEnabled() {
        let p = ToolPreferences(defaults: freshDefaults())
        XCTAssertTrue(p.isEnabled("jwt"))
    }

    func test_disable_then_persist() {
        let d = freshDefaults()
        let p = ToolPreferences(defaults: d)
        p.setEnabled(false, for: "jwt")
        XCTAssertFalse(p.isEnabled("jwt"))
        let p2 = ToolPreferences(defaults: d)
        XCTAssertFalse(p2.isEnabled("jwt"))
        p2.setEnabled(true, for: "jwt")
        XCTAssertTrue(p2.isEnabled("jwt"))
    }
}
