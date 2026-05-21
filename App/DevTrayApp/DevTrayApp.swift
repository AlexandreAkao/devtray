import SwiftUI
import DevTrayCore
import DevTrayUI
import JWTTool
import JSONTool
import Base64Tool
import URLTool
import HashTool
import UUIDTool
import TimestampTool

@main
struct DevTrayApp: App {
    @StateObject private var registry = makeRegistry()

    var body: some Scene {
        MenuBarExtra("DevTray", systemImage: "wrench.adjustable") {
            PopoverRoot()
                .environmentObject(registry)
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
    return r
}

private struct SettingsView: View {
    var body: some View {
        TabView {
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 420, height: 240)
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
            Text("Version 0.2.0")
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
