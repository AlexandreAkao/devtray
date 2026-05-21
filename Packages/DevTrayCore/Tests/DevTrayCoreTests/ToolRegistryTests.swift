import XCTest
import SwiftUI
import DevTrayCore

private enum StubTool: Tool {
    static let id: ToolID = "stub"
    static let displayName = "Stub Tool"
    static let iconName = "wrench"
    static let keywords = ["stub", "test"]
    static let category: ToolCategory = .text
    @MainActor static func makeView() -> AnyView { AnyView(Text("stub")) }
}

private enum AnotherTool: Tool {
    static let id: ToolID = "another"
    static let displayName = "Another"
    static let iconName = "hammer"
    static let keywords = ["another"]
    static let category: ToolCategory = .formatting
    @MainActor static func makeView() -> AnyView { AnyView(Text("another")) }
}

@MainActor
final class ToolRegistryTests: XCTestCase {
    func test_emptyRegistry_hasNoTools() {
        let registry = ToolRegistry()
        XCTAssertTrue(registry.tools.isEmpty)
    }

    func test_register_addsTool() {
        let registry = ToolRegistry()
        registry.register(StubTool.self)
        XCTAssertEqual(registry.tools.count, 1)
        XCTAssertEqual(registry.tools.first?.id, "stub")
    }

    func test_register_sameToolTwice_keepsOnlyOne() {
        let registry = ToolRegistry()
        registry.register(StubTool.self)
        registry.register(StubTool.self)
        XCTAssertEqual(registry.tools.count, 1)
    }

    func test_findByID_returnsMatchingTool() {
        let registry = ToolRegistry()
        registry.register(StubTool.self)
        registry.register(AnotherTool.self)
        XCTAssertEqual(registry.find(byID: "another")?.displayName, "Another")
    }

    func test_findByID_unknownID_returnsNil() {
        let registry = ToolRegistry()
        registry.register(StubTool.self)
        XCTAssertNil(registry.find(byID: "missing"))
    }

    func test_search_matchesByDisplayName() {
        let registry = ToolRegistry()
        registry.register(StubTool.self)
        registry.register(AnotherTool.self)
        XCTAssertEqual(registry.search("anot").map(\.id), ["another"])
    }

    func test_search_matchesByKeyword() {
        let registry = ToolRegistry()
        registry.register(StubTool.self)
        XCTAssertEqual(registry.search("test").map(\.id), ["stub"])
    }

    func test_search_emptyQuery_returnsAll() {
        let registry = ToolRegistry()
        registry.register(StubTool.self)
        registry.register(AnotherTool.self)
        XCTAssertEqual(registry.search("").count, 2)
    }

    func test_search_caseInsensitive() {
        let registry = ToolRegistry()
        registry.register(StubTool.self)
        XCTAssertEqual(registry.search("STUB").map(\.id), ["stub"])
    }
}
