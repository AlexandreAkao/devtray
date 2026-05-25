import SwiftUI
import os
import KeyboardShortcuts
import DevTrayCore
import DevTrayUI
import DevTrayStorage
import JWTTool
import JSONTool
import Base64Tool
import URLTool
import HashTool
import UUIDTool
import TimestampTool
import SnippetsTool

@main
struct DevTrayApp: App {
    @StateObject private var registry: ToolRegistry
    private let usageStore: any UsageStore = makeUsageStore()
    private let snippetStore: any SnippetStore = makeSnippetStore()
    private let preloadBus = PreloadBus()
    @State private var spotlightController: SpotlightController?

    init() {
        let registryValue = makeRegistry()
        _registry = StateObject(wrappedValue: registryValue)
        let controller = SpotlightController(
            registry: registryValue,
            usageStore: usageStore,
            snippetStore: snippetStore,
            preloadBus: preloadBus
        )
        _spotlightController = State(initialValue: controller)

        let capturedController = controller
        KeyboardShortcuts.onKeyDown(for: .toggleSpotlight) {
            capturedController.toggle()
        }
    }

    var body: some Scene {
        MenuBarExtra("DevTray", systemImage: "wrench.adjustable") {
            PopoverRoot()
                .environmentObject(registry)
                .environment(\.usageStore, usageStore)
                .environment(\.snippetStore, snippetStore)
                .environment(\.preloadBus, preloadBus)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

@MainActor
private func makeRegistry() -> ToolRegistry {
    let r = ToolRegistry()
    r.register(JWTTool.self)
    r.register(JSONTool.self)
    r.register(Base64Tool.self)
    r.register(URLTool.self)
    r.register(HashTool.self)
    r.register(UUIDTool.self)
    r.register(TimestampTool.self)
    r.register(SnippetsTool.self)
    return r
}

private func makeUsageStore() -> any UsageStore {
    do {
        return try SQLiteUsageStore.openDefault()
    } catch {
        Logger(subsystem: "com.devtray.app", category: "storage")
            .error("SQLite open failed, using in-memory store: \(error.localizedDescription, privacy: .public)")
        return InMemoryUsageStore()
    }
}

private func makeSnippetStore() -> any SnippetStore {
    do {
        return try SQLiteSnippetStore.openDefault()
    } catch {
        Logger(subsystem: "com.devtray.app", category: "storage")
            .error("SQLite snippet store open failed, using in-memory store: \(error.localizedDescription, privacy: .public)")
        return InMemorySnippetStore()
    }
}

private struct SettingsView: View {
    var body: some View {
        TabView {
            ShortcutsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 280)
    }
}

private struct ShortcutsTab: View {
    var body: some View {
        Form {
            LabeledContent("Open Spotlight") {
                KeyboardShortcuts.Recorder(for: .toggleSpotlight)
            }
            Text("Press the shortcut from any app to open DevTray's quick search.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.adjustable")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("DevTray")
                .font(.title2).fontWeight(.semibold)
            Text("Version \(AppMetadata.version)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text("MIT License · github.com/AlexandreAkao/devtray")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
    }
}
