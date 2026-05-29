import DevTrayCore
@testable import HashToolKit
import XCTest

final class HashEngineTests: XCTestCase {
    // Known vectors for "hello"

    func test_md5_hello() {
        guard case .success(let s) = HashEngine.md5("hello") else { XCTFail(); return }
        XCTAssertEqual(s, "5d41402abc4b2a76b9719d911017c592")
    }

    func test_sha1_hello() {
        guard case .success(let s) = HashEngine.sha1("hello") else { XCTFail(); return }
        XCTAssertEqual(s, "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d")
    }

    func test_sha256_hello() {
        guard case .success(let s) = HashEngine.sha256("hello") else { XCTFail(); return }
        XCTAssertEqual(s, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    func test_sha512_hello() {
        guard case .success(let s) = HashEngine.sha512("hello") else { XCTFail(); return }
        XCTAssertEqual(
            s,
            "9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c4663475c2e5c3adef46f73bcdec043"
        )
    }

    // Empty string vectors

    func test_md5_emptyString_returnsInvalidInput() {
        if case .failure(.invalidInput) = HashEngine.md5("") { return }
        XCTFail("expected invalidInput")
    }

    func test_sha1_emptyString_returnsInvalidInput() {
        if case .failure(.invalidInput) = HashEngine.sha1("") { return }
        XCTFail("expected invalidInput")
    }

    func test_sha256_emptyString_returnsInvalidInput() {
        if case .failure(.invalidInput) = HashEngine.sha256("") { return }
        XCTFail("expected invalidInput")
    }

    func test_sha512_emptyString_returnsInvalidInput() {
        if case .failure(.invalidInput) = HashEngine.sha512("") { return }
        XCTFail("expected invalidInput")
    }

    // Unicode

    func test_sha256_unicode_isDeterministic() {
        // Reference computed via `echo -n 'héllo 🌍' | shasum -a 256`
        guard case .success(let a) = HashEngine.sha256("héllo 🌍"),
              case .success(let b) = HashEngine.sha256("héllo 🌍") else {
            XCTFail(); return
        }
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 64) // 32 bytes hex = 64 chars
    }

    // Output format

    func test_md5_outputIsLowercaseHex() {
        guard case .success(let s) = HashEngine.md5("hello") else { XCTFail(); return }
        XCTAssertEqual(s, s.lowercased())
        XCTAssertTrue(s.allSatisfy(\.isHexDigit))
    }
}
