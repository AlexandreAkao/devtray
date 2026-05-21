public enum ToolError: LocalizedError, Equatable {
    case parseFailure(reason: String, hint: String?)
    case invalidInput(reason: String)
    case unsupportedOperation(String)
    case dependencyMissing(String)
    case storageFailure(message: String)

    public var errorDescription: String? {
        switch self {
        case .parseFailure(let reason, let hint):
            if let hint, !hint.isEmpty { return "\(reason) (\(hint))" }
            return reason
        case .invalidInput(let reason):
            return reason
        case .unsupportedOperation(let reason):
            return reason
        case .dependencyMissing(let reason):
            return reason
        case .storageFailure(let message):
            return message
        }
    }
}
