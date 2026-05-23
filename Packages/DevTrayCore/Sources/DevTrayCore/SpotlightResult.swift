public struct SpotlightResult: Sendable, Equatable, Identifiable {
    public let toolID: ToolID
    public let fromClipboard: Bool

    public init(toolID: ToolID, fromClipboard: Bool) {
        self.toolID = toolID
        self.fromClipboard = fromClipboard
    }

    public var id: ToolID { toolID }
}
