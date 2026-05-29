@testable import ColorToolKit
import DevTrayCore
import XCTest

final class ColorEngineTests: XCTestCase {
    private func value(_ input: String) -> ColorValue? {
        if case .success(let v) = ColorEngine.parse(input) { return v }
        return nil
    }

    func test_parseHex6() {
        let v = value("#FF8800")
        XCTAssertEqual(v?.r, 255); XCTAssertEqual(v?.g, 136); XCTAssertEqual(v?.b, 0)
        XCTAssertEqual(v?.a ?? 0, 1, accuracy: 0.001)
    }

    func test_parseHex3Expands() {
        let v = value("#F80")
        XCTAssertEqual(v?.r, 255); XCTAssertEqual(v?.g, 136); XCTAssertEqual(v?.b, 0)
    }

    func test_parseHex8Alpha() {
        let v = value("#FF880080")
        XCTAssertEqual(v?.r, 255)
        XCTAssertEqual(v?.a ?? 0, 128.0 / 255.0, accuracy: 0.01)
    }

    func test_parseRGB() {
        let v = value("rgb(255, 136, 0)")
        XCTAssertEqual(v?.r, 255); XCTAssertEqual(v?.g, 136); XCTAssertEqual(v?.b, 0)
    }

    func test_parseHSL() {
        let v = value("hsl(30, 100%, 50%)")
        XCTAssertEqual(v?.r, 255); XCTAssertEqual(v?.g, 128); XCTAssertEqual(v?.b, 0)
    }

    func test_hexOutput() {
        XCTAssertEqual(ColorValue(r: 255, g: 136, b: 0, a: 1).hex, "#FF8800")
    }

    func test_hslOutputForRed() {
        XCTAssertEqual(ColorValue(r: 255, g: 0, b: 0, a: 1).hslString, "hsl(0, 100%, 50%)")
    }

    func test_invalidInputFails() {
        guard case .failure(let error) = ColorEngine.parse("not a color") else {
            return XCTFail("expected failure")
        }
        guard case ToolError.invalidInput = error else { return XCTFail("expected invalidInput") }
    }

    func test_alphaOutputPrecision() {
        // 0xFE / 255 = 0.9961 → must NOT round to "1" in the rgba string (Fix A)
        let v = value("#FF0000FE")
        XCTAssertEqual(v?.rgbString, "rgba(255, 0, 0, 0.996)")
    }

    func test_hueIsCanonicalNot360() {
        // rgb(255,0,1) has hue ≈ 359.76 → must render as 0, not 360 (Fix B)
        XCTAssertEqual(ColorValue(r: 255, g: 0, b: 1, a: 1).hslString, "hsl(0, 100%, 50%)")
    }

    func test_parseRGBPercentages() {
        // rgb(100%, 0%, 0%) is bright red, not (100, 0, 0) (Fix C)
        let v = value("rgb(100%, 0%, 0%)")
        XCTAssertEqual(v?.r, 255); XCTAssertEqual(v?.g, 0); XCTAssertEqual(v?.b, 0)
    }
}
