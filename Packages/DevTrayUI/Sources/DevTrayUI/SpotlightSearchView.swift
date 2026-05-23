import SwiftUI
import DevTrayCore

public struct SpotlightSearchView: View {
    @StateObject private var viewModel: SpotlightViewModel
    private let onSubmit: (SpotlightResult, _ withPreload: Bool) -> Void
    private let onCancel: () -> Void
    @FocusState private var searchFocused: Bool

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
        VStack(spacing: 0) {
            searchField
            Divider()
            list
        }
        .background(.ultraThinMaterial)
        .onAppear { searchFocused = true }
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
                    .onTapGesture { onSubmit(row.result, true) }
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
        .onKeyPress(.escape) {
            onCancel(); return .handled
        }
    }

    private func handleReturn(withPreload: Bool) {
        if let id = viewModel.selectedID,
           let row = viewModel.rows.first(where: { $0.result.toolID == id })
        {
            onSubmit(row.result, withPreload)
        }
    }
}
