import SwiftUI
import AppKit
import UniformTypeIdentifiers
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
import RegexTool
import DiffTool
import ColorTool
import CronTool
import YAMLTool

@main
struct DevTrayApp: App {
    @StateObject private var registry: ToolRegistry
    @StateObject private var updater = UpdaterController()
    @StateObject private var toolPreferences: ToolPreferences
    private let usageStore: any UsageStore = makeUsageStore()
    private let snippetStore: any SnippetStore = makeSnippetStore()
    private let preloadBus = PreloadBus()
    @State private var spotlightController: SpotlightController?

    init() {
        let registryValue = makeRegistry()
        _registry = StateObject(wrappedValue: registryValue)
        let prefs = ToolPreferences()
        _toolPreferences = StateObject(wrappedValue: prefs)
        let controller = SpotlightController(
            registry: registryValue,
            usageStore: usageStore,
            snippetStore: snippetStore,
            preloadBus: preloadBus,
            toolPreferences: prefs
        )
        _spotlightController = State(initialValue: controller)

        let capturedController = controller
        KeyboardShortcuts.onKeyDown(for: .toggleSpotlight) {
            capturedController.toggle()
        }
    }

    var body: some Scene {
        MenuBarExtra("DevTray", systemImage: "wrench.adjustable") {
            PopoverRoot(
                onCheckForUpdates: { updater.checkForUpdates() },
                canCheckForUpdates: updater.canCheckForUpdates
            )
                .environmentObject(registry)
                .environmentObject(toolPreferences)
                .environment(\.usageStore, usageStore)
                .environment(\.snippetStore, snippetStore)
                .environment(\.preloadBus, preloadBus)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(\.snippetStore, snippetStore)
                .environmentObject(updater)
                .environmentObject(registry)
                .environmentObject(toolPreferences)
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
    r.register(RegexTool.self)
    r.register(DiffTool.self)
    r.register(ColorTool.self)
    r.register(CronTool.self)
    r.register(YAMLTool.self)
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
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            ToolsTab()
                .tabItem { Label("Tools", systemImage: "square.grid.2x2") }
            ShortcutsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 400)
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

private struct GeneralTab: View {
    @Environment(\.snippetStore) private var store: any SnippetStore
    @State private var status: String?
    @State private var isError = false

    var body: some View {
        Form {
            Section("Snippets") {
                LabeledContent("Backup") {
                    HStack {
                        Button("Export snippets…") { exportSnippets() }
                        Button("Import snippets…") { importSnippets() }
                    }
                }
                Text("Export writes a JSON file you can import on another Mac. Import merges by id — existing snippets with the same id are updated, new ones are added.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let status {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(isError ? .red : .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func exportSnippets() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "DevTray-snippets-\(Self.dateStamp()).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let snippets = try await store.all()
                let data = try SnippetArchive.encode(snippets, exportedAt: .now)
                try data.write(to: url, options: .atomic)
                report("Exported \(snippets.count) snippet\(snippets.count == 1 ? "" : "s").", isError: false)
            } catch {
                report(error.localizedDescription, isError: true)
            }
        }
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let data = try Data(contentsOf: url)
                let snippets = try SnippetArchive.decode(data)
                for snippet in snippets {
                    try await store.save(snippet)
                }
                report("Imported \(snippets.count) snippet\(snippets.count == 1 ? "" : "s").", isError: false)
            } catch {
                report(error.localizedDescription, isError: true)
            }
        }
    }

    private func report(_ message: String, isError: Bool) {
        self.status = message
        self.isError = isError
    }

    private static func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}

private struct ToolsTab: View {
    @EnvironmentObject private var registry: ToolRegistry
    @EnvironmentObject private var toolPreferences: ToolPreferences

    var body: some View {
        Form {
            Section("Enabled tools") {
                ForEach(registry.tools) { tool in
                    Toggle(isOn: Binding(
                        get: { toolPreferences.isEnabled(tool.id) },
                        set: { toolPreferences.setEnabled($0, for: tool.id) }
                    )) {
                        Label(tool.displayName, systemImage: tool.iconName)
                    }
                }
            }
            Text("Disabled tools are hidden from the popover and Spotlight.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AboutTab: View {
    @EnvironmentObject private var updater: UpdaterController

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
            Button("Check for Updates…") { updater.checkForUpdates() }
                .disabled(!updater.canCheckForUpdates)
            Spacer()
            Text("MIT License · github.com/AlexandreAkao/devtray")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
    }
}
