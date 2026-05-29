import Foundation
import DevTrayCore

enum RSAKey {
    static func verify(signingInput: Data, signature: Data, pemPublicKey: String) -> Result<Bool, ToolError> {
        .failure(.unsupportedOperation("RS256 not yet implemented"))
    }
    static func sign(signingInput: Data, pemPrivateKey: String) -> Result<Data, ToolError> {
        .failure(.unsupportedOperation("RS256 not yet implemented"))
    }
}
