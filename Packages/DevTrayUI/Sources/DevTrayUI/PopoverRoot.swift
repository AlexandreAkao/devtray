import SwiftUI
import DevTrayCore

public struct PopoverRoot: View {
    @EnvironmentObject private var registry: ToolRegistry
    @State private var searchText: String = ""
    @State private var selectedToolID: ToolID?

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
        .onAppear {
            if selectedToolID == nil {
                selectedToolID = filteredTools.first?.id
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
        HStack {
            Text("DevTray v0.2.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var filteredTools: [AnyTool] {
        registry.search(searchText)
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
