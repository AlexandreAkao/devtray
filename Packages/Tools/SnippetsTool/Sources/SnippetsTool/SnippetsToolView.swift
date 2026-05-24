import SwiftUI
import DevTrayCore

public struct SnippetsToolView: View {
    @Environment(\.snippetStore) private var snippetStore: any SnippetStore
    @State private var model: SnippetsModel?

    public init() {}

    public var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .frame(minWidth: 360, minHeight: 320)
        .task {
            if model == nil {
                let m = SnippetsModel(store: snippetStore)
                model = m
                await m.reload()
            }
        }
    }

    @ViewBuilder
    private func content(_ model: SnippetsModel) -> some View {
        VStack(spacing: 0) {
            SnippetsListView(model: model)
            if let snippet = model.selectedSnippet {
                Divider()
                SnippetEditorView(model: model, snippet: snippet)
            }
        }
    }
}
