import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleSpotlight = Self(
        "toggleSpotlight",
        default: .init(.space, modifiers: [.option, .command])
    )
}
