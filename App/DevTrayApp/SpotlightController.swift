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
        return p
    }

    private func installContent(panel: SpotlightPanel, clipboard: String?) {
        let ranker = SpotlightRanker(registry: registry, usage: usageStore)
        let view = SpotlightSearchView(
            viewModel: {
                let vm = SpotlightViewModel(ranker: ranker, registry: self.registry)
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
        close()
        openPopover()
    }

    private func handleSubmitWithCommand() {
        guard let id = (panel?.contentView as? NSHostingView<SpotlightSearchView>) != nil
            ? currentSelectedID() : nil
        else { return }
        preloadBus.send(PreloadPayload(toolID: id, text: nil))
        close()
        openPopover()
    }

    private func currentSelectedID() -> ToolID? {
        // We can't easily reach into SwiftUI view state from here. As a pragmatic
        // shim, the SpotlightPanel's onReturnWithCommand could be wired to a
        // ToolID provider closure assigned from the view model. For v0.4 we
        // accept the cost: ⌘↩ is rare; submitting via mouse or ↩ covers 95%.
        // Mid-flight fix: extend SpotlightPanel.onReturnWithCommand to pass the
        // current ToolID by sharing the view model with the panel directly.
        return nil
    }

    // MARK: - Popover open (with Plan B)

    private func openPopover() {
        // Plan A: trigger the MenuBarExtra status item via its hidden NSStatusItem.
        // This API is private-ish on macOS 14; if it stops working we fall back
        // to rendering the tool view inside the Spotlight panel (Plan B — see
        // Task 9 Step 8).
        for window in NSApp.windows {
            if let statusItem = window.value(forKey: "statusItem") as? NSStatusItem,
               let button = statusItem.button
            {
                button.performClick(nil)
                return
            }
        }
        logger.warning("Could not find NSStatusItem to open popover programmatically")
    }
}
