import XCTest
import DevTrayCore

final class ToolCategoryTests: XCTestCase {
    func test_allCases_includesGenerators() {
        XCTAssertTrue(ToolCategory.allCases.contains(.generators))
    }

    func test_generators_displayName_isGenerators() {
        XCTAssertEqual(ToolCategory.generators.displayName, "Generators")
    }

    func test_allCases_displayNames_areNonEmpty() {
        for category in ToolCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty,
                           "Category \(category) has empty displayName")
        }
    }
}
