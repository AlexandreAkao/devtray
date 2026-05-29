@testable import HashToolKit
import XCTest

final class HashDataTests: XCTestCase {
    func test_sha256_ofData_matchesKnownVector() {
        // sha256("abc")
        let r = HashEngine.sha256(data: Data("abc".utf8))
        XCTAssertEqual(try? r.get(), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func test_md5_ofEmptyData_isError() {
        if case .success = HashEngine.md5(data: Data()) { XCTFail("empty should error") }
    }
}
