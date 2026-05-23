import SwiftUI
import DevTrayCore

public struct PopoverRoot: View {
    @EnvironmentObject private var registry: ToolRegistry
    @Environment(\.usageStore) private var usageStore
    @Environment(\.preloadBus) private var preloadBus: PreloadBus

    @State private var searchText: String = ""
    @State private var selectedToolID: ToolID?
    @State private var topTools: [ToolUsageRank] = []
    @State private var hasBootstrapped: Bool = false

    public init() {}

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
                selectedToolID = filteredTools.first?.id
            }
            hasBootstrapped = true
        }
        .onReceive(preloadBus.$pending) { payload in
            guard let payload else { return }
            selectedToolID = payload.toolID
            // Text consumption happens inside the tool view, not here.
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
                ForEach(filteredTools) { tool in
                    SidebarRow(tool: tool, isSelected: tool.id == selectedToolID)
                        .onTapGesture { selectedToolID = tool.id }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
        }
        .frame(width: 130)
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
                if let tool = registry.find(byID: rank.toolID) {
                    FrequentToolChip(tool: tool) {
                        selectedToolID = tool.id
                    }
                }
            }
            Spacer()
            Text("DevTray v\(AppMetadata.version)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 32)
    }

    private var filteredTools: [AnyTool] {
        registry.search(searchText)
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
