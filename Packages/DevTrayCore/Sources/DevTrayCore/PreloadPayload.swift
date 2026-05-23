public struct PreloadPayload: Sendable, Equatable {
    public let toolID: ToolID
    public let text: String?

    public init(toolID: ToolID, text: String?) {
        self.toolID = toolID
        self.text = text
    }
}
