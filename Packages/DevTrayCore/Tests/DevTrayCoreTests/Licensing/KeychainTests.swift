@testable import DevTrayCore
import XCTest

final class InMemoryKeychainTests: XCTestCase {
    func test_setThenGet_returnsValue() throws {
        let kc = InMemoryKeychain()
        try kc.set(Data("hello".utf8), account: "license_jwt")
        XCTAssertEqual(try kc.get(account: "license_jwt"), Data("hello".utf8))
    }

    func test_get_missingAccount_returnsNil() throws {
        let kc = InMemoryKeychain()
        XCTAssertNil(try kc.get(account: "nope"))
    }

    func test_set_overwritesExistingValue() throws {
        let kc = InMemoryKeychain()
        try kc.set(Data("a".utf8), account: "k")
        try kc.set(Data("b".utf8), account: "k")
        XCTAssertEqual(try kc.get(account: "k"), Data("b".utf8))
    }

    func test_delete_removesValue() throws {
        let kc = InMemoryKeychain()
        try kc.set(Data("x".utf8), account: "k")
        try kc.delete(account: "k")
        XCTAssertNil(try kc.get(account: "k"))
    }

    func test_delete_missingAccount_isNoOp() throws {
        let kc = InMemoryKeychain()
        XCTAssertNoThrow(try kc.delete(account: "nope"))
    }
}
