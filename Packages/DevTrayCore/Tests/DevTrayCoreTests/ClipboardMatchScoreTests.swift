@testable import DevTrayCore
import SwiftUI
import XCTest

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

extension ClipboardMatchScoreTests {
    func test_anyTool_clipboardMatch_callsConcreteOverride() {
        // Regression: AnyTool's captured closure must use witness-table dispatch
        // so the conforming type's override is reached. If clipboardMatch lives
        // only in a protocol extension (not the protocol body), this test fails
        // because static dispatch resolves to the default `nil` implementation.
        let any = AnyTool(OverrideStubTool.self)
        XCTAssertEqual(any.clipboardMatch("trigger")?.confidence, .strong)
        XCTAssertNil(any.clipboardMatch("other"))
    }
}

private enum OverrideStubTool: Tool {
    static let id: ToolID = "override-stub"
    static let displayName = "Override Stub"
    static let iconName = "questionmark"
    static let keywords: [String] = []
    static let category: ToolCategory = .text
    @MainActor static func makeView() -> AnyView { AnyView(EmptyView()) }
    static func clipboardMatch(_ clipboard: String) -> ClipboardMatchScore? {
        clipboard == "trigger" ? ClipboardMatchScore(.strong) : nil
    }
}
