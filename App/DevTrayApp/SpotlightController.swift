import AppKit
import SwiftUI
import os
import DevTrayCore
import DevTrayUI

@MainActor
final class SpotlightController {
    private let registry: ToolRegistry
    private let usageStore: any UsageStore
    private let preloadBus: PreloadBus
    private var panel: SpotlightPanel?
    private var resignObserver: Any?
    private let logger = Logger(subsystem: "com.devtray.app", category: "spotlight")

    init(registry: ToolRegistry, usageStore: any UsageStore, preloadBus: PreloadBus) {
        self.registry = registry
        self.usageStore = usageStore
        self.preloadBus = preloadBus
    }

    func toggle() {
        if let panel, panel.isVisible {
            close()
        } else {
            open()
        }
    }

    private func open() {
        let clipboard = NSPasteboard.general.string(forType: .string)
        let panel = panel ?? makePanel()
        self.panel = panel
        installContent(panel: panel, clipboard: clipboard)
        positionPanel(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
        installResignObserver(for: panel)
    }

    private func close() {
        if let token = resignObserver {
            NotificationCenter.default.removeObserver(token)
            resignObserver = nil
        }
        panel?.orderOut(nil)
    }

    private func makePanel() -> SpotlightPanel {
        let p = SpotlightPanel()
        p.onReturnWithCommand = { [weak self] in
            self?.handleSubmitWithCommand()
        }
        p.onCancel = { [weak self] in
            self?.close()
        }
        return p
    }

    private func installContent(panel: SpotlightPanel, clipboard: String?) {
        let ranker = SpotlightRanker(registry: registry, usage: usageStore)
        let capturedRegistry = registry
        let view = SpotlightSearchView(
            viewModel: { [capturedRegistry] in
                let vm = SpotlightViewModel(ranker: ranker, registry: capturedRegistry)
                vm.onOpen(clipboard: clipboard)
                return vm
            },
            onSubmit: { [weak self] result, withPreload in
                self?.handleSubmit(result: result, withPreload: withPreload)
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        let host = NSHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = true
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
    }

    private func positionPanel(_ panel: SpotlightPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let x = frame.midX - size.width / 2
        let y = frame.maxY - size.height - frame.height * 0.20
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func installResignObserver(for panel: SpotlightPanel) {
        if let token = resignObserver {
            NotificationCenter.default.removeObserver(token)
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.close()
        }
    }

    // MARK: - Submit handling

    private func handleSubmit(result: SpotlightResult, withPreload: Bool) {
        let text: String?
        if withPreload, let cb = NSPasteboard.general.string(forType: .string) {
            text = cb
        } else {
            text = nil
        }
        preloadBus.send(PreloadPayload(toolID: result.toolID, text: text))
        // Plan B: panel hosts the tool view inline; do not close + open popover.
    }

    /// v0.4 limitation: ⌘↩ from the keyboard is a no-op because we can't reach
    /// into the SwiftUI view's `selectedID` from the AppKit `keyDown` override.
    /// The bare `↩` path (via `onKeyPress(.return)` inside `SpotlightSearchView`)
    /// and the mouse-tap path cover the common cases. A future iteration can
    /// thread the current ToolID through `SpotlightPanel.onReturnWithCommand`
    /// by sharing the view model with the panel directly.
    private func handleSubmitWithCommand() {
        guard let id = currentSelectedID() else { return }
        preloadBus.send(PreloadPayload(toolID: id, text: nil))
    }

    private func currentSelectedID() -> ToolID? {
        // Always nil for v0.4 — see handleSubmitWithCommand header.
        return nil
    }
}
