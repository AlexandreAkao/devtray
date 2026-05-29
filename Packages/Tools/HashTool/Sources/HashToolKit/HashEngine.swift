import Foundation
import CryptoKit
import DevTrayCore

public enum HashEngine {
    public static func md5(_ raw: String) -> Result<String, ToolError> { md5(data: Data(raw.utf8)) }
    public static func sha1(_ raw: String) -> Result<String, ToolError> { sha1(data: Data(raw.utf8)) }
    public static func sha256(_ raw: String) -> Result<String, ToolError> { sha256(data: Data(raw.utf8)) }
    public static func sha512(_ raw: String) -> Result<String, ToolError> { sha512(data: Data(raw.utf8)) }

    public static func md5(data: Data) -> Result<String, ToolError> { compute(data) { Insecure.MD5.hash(data: $0) } }
    public static func sha1(data: Data) -> Result<String, ToolError> { compute(data) { Insecure.SHA1.hash(data: $0) } }
    public static func sha256(data: Data) -> Result<String, ToolError> { compute(data) { SHA256.hash(data: $0) } }
    public static func sha512(data: Data) -> Result<String, ToolError> { compute(data) { SHA512.hash(data: $0) } }

    private static func compute<D: Digest>(_ data: Data, digest: (Data) -> D) -> Result<String, ToolError> {
        guard !data.isEmpty else { return .failure(.invalidInput(reason: "Input is empty")) }
        return .success(digest(data).map { String(format: "%02x", $0) }.joined())
    }
}
