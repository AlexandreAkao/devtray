import DevTrayCore
import SwiftUI

public struct PopoverRoot: View {
    @EnvironmentObject private var registry: ToolRegistry
    @EnvironmentObject private var toolPreferences: ToolPreferences
    @Environment(\.usageStore) private var usageStore
    @Environment(\.preloadBus) private var preloadBus: PreloadBus

    @State private var searchText: String = ""
    @State private var selectedToolID: ToolID?
    @State private var topTools: [ToolUsageRank] = []
    @State private var hasBootstrapped: Bool = false

    private let onCheckForUpdates: (() -> Void)?
    private let canCheckForUpdates: Bool

    public init(
        onCheckForUpdates: (() -> Void)? = nil,
        canCheckForUpdates: Bool = false
    ) {
        self.onCheckForUpdates = onCheckForUpdates
        self.canCheckForUpdates = canCheckForUpdates
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sidebar
                Divider()
                workspace
            }
            Divider()
            footer
        }
        .frame(width: 560, height: 540)
        .task { await refreshTopTools() }
        .onChange(of: selectedToolID) { _, newValue in
            guard hasBootstrapped, let id = newValue else { return }
            Task { await usageStore.record(toolID: id, at: .now) }
        }
        .onAppear {
            if selectedToolID == nil {
                selectedToolID = visibleTools.first?.id
            }
            hasBootstrapped = true
        }
        .onReceive(preloadBus.$pending) { payload in
            guard let payload else { return }
            selectedToolID = payload.toolID
            // Text consumption happens inside the tool view, not here.
        }
        .onChange(of: toolPreferences.disabledIDs) { _, _ in
            if let id = selectedToolID, !toolPreferences.isEnabled(id) {
                selectedToolID = visibleTools.first?.id
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search tools", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(.body))
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                if visibleTools.isEmpty {
                    Text("All tools are disabled.\nEnable some in Settings → Tools.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(8)
                } else if isSearching {
                    ForEach(visibleTools) { tool in row(tool) }
                } else {
                    ForEach(groupedTools, id: \.category) { group in
                        Text(group.category.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.top, 6)
                        ForEach(group.tools) { tool in row(tool) }
                    }
                }
            }
            .padding(.vertical, 6).padding(.horizontal, 6)
        }
        .frame(width: 150)
        .background(cmdNumberShortcuts)
    }

    private func row(_ tool: AnyTool) -> some View {
        SidebarRow(tool: tool, isSelected: tool.id == selectedToolID)
            .onTapGesture { selectedToolID = tool.id }
    }

    /// Hidden buttons binding Cmd+1…9 to the first nine visible tools.
    private var cmdNumberShortcuts: some View {
        ForEach(Array(visibleTools.prefix(9).enumerated()), id: \.element.id) { idx, tool in
            Button("") { selectedToolID = tool.id }
                .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")), modifiers: .command)
                .hidden()
        }
    }

    private var workspace: some View {
        Group {
            if let id = selectedToolID, let tool = registry.find(byID: id) {
                tool.makeView()
                    .id(id.rawValue)
                    .padding(12)
            } else {
                ContentUnavailableView(
                    "No tool selected",
                    systemImage: "wrench.adjustable",
                    description: Text("Pick a tool from the sidebar.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            ForEach(topTools, id: \.toolID) { rank in
                if let tool = registry.find(byID: rank.toolID), toolPreferences.isEnabled(tool.id) {
                    FrequentToolChip(tool: tool) {
                        selectedToolID = tool.id
                    }
                }
            }
            Spacer()
            if let onCheckForUpdates {
                Button("Check for Updates…", action: onCheckForUpdates)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .disabled(!canCheckForUpdates)
            }
            Text("DevTray v\(AppMetadata.version)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 32)
    }

    /// Flat list honoring search + enabled state (used for selection + Cmd+1…9).
    private var visibleTools: [AnyTool] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return toolPreferences.enabled(registry.search(q))
    }

    /// Grouped by category for the no-search sidebar.
    private var groupedTools: [(category: ToolCategory, tools: [AnyTool])] {
        let visible = visibleTools
        return ToolCategory.allCases.compactMap { cat in
            let inCat = visible.filter { $0.category == cat }
            return inCat.isEmpty ? nil : (cat, inCat)
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func refreshTopTools() async {
        let result = try? await usageStore.topTools(
            window: .lastDays(30), limit: 3, now: .now
        )
        topTools = result ?? []
    }
}

private struct SidebarRow: View {
    let tool: AnyTool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tool.iconName)
                .frame(width: 16)
                .foregroundStyle(isSelected ? .white : .primary)
            Text(tool.displayName)
                .font(.system(.callout))
                .foregroundStyle(isSelected ? .white : .primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
