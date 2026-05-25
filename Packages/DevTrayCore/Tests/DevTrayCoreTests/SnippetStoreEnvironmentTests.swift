import XCTest
import SwiftUI
@testable import DevTrayCore

final class SnippetStoreEnvironmentTests: XCTestCase {
    func test_default_isUsableEmptyStore() async throws {
        let env = EnvironmentValues()
        let store = env.snippetStore
        let all = try await store.all()
        XCTAssertTrue(all.isEmpty)
    }
}
