import Foundation

internal enum Base64URL {
    static func decode(_ input: String) -> Data? {
        var s = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - s.count % 4) % 4
        s.append(String(repeating: "=", count: padding))
        return Data(base64Encoded: s)
    }
}
