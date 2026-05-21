import Foundation

public struct DecodedJWT: Equatable {
    public let headerJSON: String
    public let payloadJSON: String
    public let signature: String
    public let algorithm: String?

    public init(headerJSON: String, payloadJSON: String, signature: String, algorithm: String?) {
        self.headerJSON = headerJSON
        self.payloadJSON = payloadJSON
        self.signature = signature
        self.algorithm = algorithm
    }
}
