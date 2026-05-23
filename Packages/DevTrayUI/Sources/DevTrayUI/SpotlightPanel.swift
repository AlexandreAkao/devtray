import AppKit
import SwiftUI

public final class SpotlightPanel: NSPanel {
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 380),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled],
            backing: .buffered,
            defer: false
        )
        level = .popUpMenu
        isFloatingPanel = true
        hidesOnDeactivate = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .clear
        isMovableByWindowBackground = false
        isOpaque = false
        hasShadow = true
        animationBehavior = .utilityWindow
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    /// Called by the controller before sending the regular `keyDown` to AppKit.
    /// Allows intercepting `⌘↩` for "navigate without preload".
    public var onReturnWithCommand: (() -> Void)?

    public override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36
        let isCommand = event.modifierFlags.contains(.command)
        if isReturn && isCommand {
            onReturnWithCommand?()
            return
        }
        super.keyDown(with: event)
    }
}
