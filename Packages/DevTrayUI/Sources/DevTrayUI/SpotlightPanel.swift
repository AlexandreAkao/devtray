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

    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { false }

    public var onCancel: (() -> Void)?

    override public func cancelOperation(_: Any?) {
        onCancel?()
    }
}
