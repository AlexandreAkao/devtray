import Foundation
import CryptoKit
import DevTrayCore

public enum HashEngine {
    public static func md5(_ raw: String) -> Result<String, ToolError> {
        compute(raw) { data in Insecure.MD5.hash(data: data) }
    }

    public static func sha1(_ raw: String) -> Result<String, ToolError> {
        compute(raw) { data in Insecure.SHA1.hash(data: data) }
    }

    public static func sha256(_ raw: String) -> Result<String, ToolError> {
        compute(raw) { data in SHA256.hash(data: data) }
    }

    public static func sha512(_ raw: String) -> Result<String, ToolError> {
        compute(raw) { data in SHA512.hash(data: data) }
    }

    private static func compute<D: Digest>(
        _ raw: String,
        digest: (Data) -> D
    ) -> Result<String, ToolError> {
        guard !raw.isEmpty else {
            return .failure(.invalidInput(reason: "Input is empty"))
        }
        let data = Data(raw.utf8)
        let bytes = digest(data)
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        return .success(hex)
    }
}
