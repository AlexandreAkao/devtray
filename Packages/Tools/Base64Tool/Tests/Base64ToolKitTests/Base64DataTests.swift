@testable import Base64ToolKit
import XCTest

final class Base64DataTests: XCTestCase {
    func test_encode_data() {
        XCTAssertEqual(Base64Engine.encode(Data("abc".utf8)), "YWJj")
    }
}
