import DevTrayCore
import SwiftUI

public struct SpotlightSearchView: View {
    @StateObject private var viewModel: SpotlightViewModel
    private let onSubmit: (SpotlightResult, _ withPreload: Bool) -> Void
    private let onCancel: () -> Void
    @FocusState private var searchFocused: Bool

    private enum Mode: Equatable {
        case list
        case tool(ToolID)
    }

    @State private var mode: Mode = .list

    public init(
        viewModel: @escaping () -> SpotlightViewModel,
        onSubmit: @escaping (SpotlightResult, _ withPreload: Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        Group {
            switch mode {
            case .list:
                listMode
            case .tool(let id):
                toolMode(id: id)
            }
        }
        .background(.ultraThinMaterial)
        .onAppear {
            DispatchQueue.main.async {
                searchFocused = true
            }
        }
    }

    private var listMode: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            list
        }
    }

    private func toolMode(id: ToolID) -> some View {
        VStack(spacing: 0) {
            toolHeader(id: id)
            Divider()
            if let tool = viewModel.tool(for: id) {
                tool.makeView()
                    .padding(12)
            } else {
                ContentUnavailableView(
                    "Tool not found",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .onKeyPress(.escape) {
            mode = .list
            return .handled
        }
    }

    private func toolHeader(id: ToolID) -> some View {
        HStack(spacing: 8) {
            Button(action: { mode = .list }) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            if let tool = viewModel.tool(for: id) {
                Image(systemName: tool.iconName)
                    .foregroundStyle(.secondary)
                Text(tool.displayName)
                    .font(.headline)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search tools…", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .regular))
                .focused($searchFocused)
                .onChange(of: viewModel.query) { _, _ in
                    viewModel.onQueryChanged()
                }
                .onSubmit { handleReturn(withPreload: true) }
                .onKeyPress(phases: .down) { press in
                    guard press.key == .return, press.modifiers.contains(.command) else { return .ignored }
                    handleReturn(withPreload: false)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    viewModel.moveSelection(by: -1); return .handled
                }
                .onKeyPress(.downArrow) {
                    viewModel.moveSelection(by: 1); return .handled
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.rows, id: \.result.toolID) { row in
                    SpotlightRow(
                        result: row.result,
                        tool: row.tool,
                        isSelected: row.result.toolID == viewModel.selectedID
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSubmit(row.result, true)
                        mode = .tool(row.result.toolID)
                    }
                }
            }
            .padding(6)
        }
        .frame(minHeight: 220)
        .onKeyPress(.upArrow) {
            viewModel.moveSelection(by: -1); return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.moveSelection(by: 1); return .handled
        }
        .onKeyPress(.return) {
            handleReturn(withPreload: true); return .handled
        }
        .onKeyPress(phases: .down) { press in
            guard press.key == .return, press.modifiers.contains(.command) else { return .ignored }
            handleReturn(withPreload: false); return .handled
        }
    }

    private func handleReturn(withPreload: Bool) {
        if let id = viewModel.selectedID,
           let row = viewModel.rows.first(where: { $0.result.toolID == id }) {
            // Still fire onSubmit so the controller can call preloadBus.send,
            // but switch to inline tool view instead of opening the popover.
            onSubmit(row.result, withPreload)
            mode = .tool(row.result.toolID)
        }
    }
}
