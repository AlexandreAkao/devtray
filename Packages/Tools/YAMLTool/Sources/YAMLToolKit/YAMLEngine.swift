import DevTrayCore
import Foundation
import Yams

public enum YAMLEngine {
    public static func yamlToJSON(_ yaml: String) -> Result<String, ToolError> {
        do {
            guard let object = try Yams.load(yaml: yaml, Resolver.default.removing(.timestamp)) else {
                return .failure(.parseFailure(reason: "YAML is empty or null.", hint: nil))
            }
            let data = try JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
            guard let string = String(data: data, encoding: .utf8) else {
                return .failure(.parseFailure(reason: "Could not encode JSON output.", hint: nil))
            }
            return .success(string)
        } catch {
            return .failure(.parseFailure(reason: error.localizedDescription, hint: nil))
        }
    }

    public static func jsonToYAML(_ json: String) -> Result<String, ToolError> {
        do {
            let raw = try JSONSerialization.jsonObject(with: Data(json.utf8), options: [.fragmentsAllowed])
            let native = toNative(raw)
            return try .success(Yams.dump(object: native))
        } catch {
            return .failure(.parseFailure(reason: error.localizedDescription, hint: nil))
        }
    }

    /// Recursively converts JSONSerialization's ObjC-backed types (NSDictionary, NSArray, NSNumber, NSString)
    /// into native Swift types that Yams can represent.
    private static func toNative(_ value: Any) -> Any {
        switch value {
        case let dict as NSDictionary:
            var result: [String: Any] = [:]
            for (k, v) in dict {
                result["\(k)"] = toNative(v)
            }
            return result
        case let array as NSArray:
            return array.map { toNative($0) }
        case let number as NSNumber:
            // Distinguish bool from numeric
            if number === kCFBooleanTrue as AnyObject { return true }
            if number === kCFBooleanFalse as AnyObject { return false }
            // Use Int if lossless, otherwise Double
            let doubleVal = number.doubleValue
            let intVal = number.intValue
            if Double(intVal) == doubleVal {
                return intVal
            }
            return doubleVal
        case let string as NSString:
            return string as String
        case is NSNull:
            return NSNull()
        default:
            return value
        }
    }
}
