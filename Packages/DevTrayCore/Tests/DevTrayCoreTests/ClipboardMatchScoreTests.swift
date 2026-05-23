import XCTest
import SwiftUI
@testable import DevTrayCore

final class ClipboardMatchScoreTests: XCTestCase {
    func test_confidenceOrdering_weakLessThanStrong() {
        XCTAssertLessThan(
            ClipboardMatchScore.Confidence.weak,
            ClipboardMatchScore.Confidence.strong
        )
    }

    func test_scoreEquality_byConfidence() {
        XCTAssertEqual(
            ClipboardMatchScore(.weak),
            ClipboardMatchScore(.weak)
        )
        XCTAssertNotEqual(
            ClipboardMatchScore(.weak),
            ClipboardMatchScore(.strong)
        )
    }
}

extension ClipboardMatchScoreTests {
    func test_anyTool_clipboardMatch_defaultIsNil() {
        let any = AnyTool(StubTool.self)
        XCTAssertNil(any.clipboardMatch("anything"))
    }
}

private enum StubTool: Tool {
    static let id: ToolID = "stub"
    static let displayName = "Stub"
    static let iconName = "questionmark"
    static let keywords: [String] = []
    static let category: ToolCategory = .text
    @MainActor static func makeView() -> AnyView { AnyView(EmptyView()) }
}
