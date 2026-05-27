import XCTest
import DevTrayCore
@testable import YAMLToolKit

final class YAMLEngineTests: XCTestCase {
    func test_yamlToJSON_map() {
        guard case .success(let json) = YAMLEngine.yamlToJSON("name: Alex\nage: 30") else {
            return XCTFail("expected success")
        }
        XCTAssertTrue(json.contains("\"name\" : \"Alex\""))
        XCTAssertTrue(json.contains("\"age\" : 30"))
    }

    func test_yamlToJSON_sequence() {
        guard case .success(let json) = YAMLEngine.yamlToJSON("- 1\n- 2\n- 3") else {
            return XCTFail("expected success")
        }
        XCTAssertTrue(json.contains("1"))
        XCTAssertTrue(json.contains("3"))
    }

    func test_jsonToYAML_map() {
        guard case .success(let yaml) = YAMLEngine.jsonToYAML("{\"a\": 1, \"b\": 2}") else {
            return XCTFail("expected success")
        }
        XCTAssertTrue(yaml.contains("a: 1"))
        XCTAssertTrue(yaml.contains("b: 2"))
    }

    func test_roundTrip_nested() {
        let yaml = "person:\n  name: Bob\n  pets:\n    - cat\n    - dog"
        guard case .success(let json) = YAMLEngine.yamlToJSON(yaml),
              case .success(let back) = YAMLEngine.jsonToYAML(json) else {
            return XCTFail("expected success")
        }
        XCTAssertTrue(back.contains("name: Bob"))
        XCTAssertTrue(back.contains("cat"))
    }

    func test_malformedYAMLFails() {
        guard case .failure(let error) = YAMLEngine.yamlToJSON("{ unclosed") else {
            return XCTFail("expected failure")
        }
        guard case ToolError.parseFailure = error else { return XCTFail("expected parseFailure") }
    }

    func test_malformedJSONFails() {
        guard case .failure(let error) = YAMLEngine.jsonToYAML("{not json") else {
            return XCTFail("expected failure")
        }
        guard case ToolError.parseFailure = error else { return XCTFail("expected parseFailure") }
    }

    func test_yamlToJSON_timestampHandledGracefully() {
        // A date scalar must NOT produce a cryptic ObjC error.
        switch YAMLEngine.yamlToJSON("created: 2023-01-15") {
        case .success(let json):
            XCTAssertTrue(json.contains("2023-01-15"))   // resolver approach: date kept as a string
        case .failure(let error):
            guard case ToolError.parseFailure(let reason, _) = error else { return XCTFail("expected parseFailure") }
            XCTAssertFalse(reason.contains("__NS"), "error message must be human-readable, not a raw ObjC type")
        }
    }

    func test_jsonToYAML_preservesBoolAndNull() {
        guard case .success(let yaml) = YAMLEngine.jsonToYAML("{\"flag\": true, \"n\": null}") else {
            return XCTFail("expected success")
        }
        XCTAssertTrue(yaml.contains("flag: true"))   // must be Bool true, not integer 1
        XCTAssertTrue(yaml.contains("n: null"))
    }
}
