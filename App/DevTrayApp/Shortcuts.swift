import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // ⌥⌘Space collides with Finder's "Show Finder Search Window" on macOS.
    // ⌃⌥Space is unbound by default and ergonomic.
    static let toggleSpotlight = Self(
        "toggleSpotlight",
        default: .init(.space, modifiers: [.control, .option])
    )
}
