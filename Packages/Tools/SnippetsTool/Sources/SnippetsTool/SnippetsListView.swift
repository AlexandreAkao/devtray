import DevTrayCore
import DevTrayUI
import SwiftUI

struct SnippetsListView: View {
    @Bindable var model: SnippetsModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Search snippets", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: model.query) { _, _ in
                        Task { await model.reload() }
                    }
                Toggle(isOn: $model.showFavoritesOnly) {
                    Image(systemName: model.showFavoritesOnly ? "star.fill" : "star")
                }
                .toggleStyle(.button)
                .help("Show favorites only")

                Button {
                    Task { await model.createAndSelect() }
                } label: {
                    Image(systemName: "plus")
                }
                .help("New snippet")
            }

            if let error = model.error {
                InlineErrorBanner(error: error)
            }

            List(selection: $model.selectedID) {
                ForEach(model.visibleSnippets) { snippet in
                    SnippetRow(snippet: snippet) {
                        Task { await model.toggleFavorite(snippet) }
                    }
                    .tag(snippet.id)
                }
            }
            .listStyle(.inset)
        }
        .padding(12)
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggleFavorite) {
                Image(systemName: snippet.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(snippet.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                    .lineLimit(1)
                if !snippet.tags.isEmpty {
                    Text(snippet.tags.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let language = snippet.language, !language.isEmpty {
                Text(language)
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}
