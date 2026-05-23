public struct PreloadPayload: Sendable, Equatable {
    public let toolID: ToolID
    /// Text to pre-fill into the target tool's primary input.
    /// `nil` means navigate to the tool without pre-filling.
    public let text: String?

    public init(toolID: ToolID, text: String?) {
        self.toolID = toolID
        self.text = text
    }
}
