public struct ClipboardMatchScore: Sendable, Equatable {
    public enum Confidence: Int, Sendable, Comparable {
        case weak
        case strong

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public let confidence: Confidence

    public init(_ confidence: Confidence) {
        self.confidence = confidence
    }
}
