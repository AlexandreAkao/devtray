import SwiftUI
import DevTrayCore
import DevTrayUI

struct SnippetEditorView: View {
    @Bindable var model: SnippetsModel
    let snippet: Snippet

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var language: String = ""
    @State private var tagsText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                TextField("Language (optional)", text: $language)
                    .textFieldStyle(.roundedBorder)
                TextField("Tags (comma separated)", text: $tagsText)
                    .textFieldStyle(.roundedBorder)
            }

            CodeEditor(text: $content, placeholder: "Snippet content", minHeight: 120)

            HStack {
                Button("Save") { save() }
                    .keyboardShortcut("s", modifiers: .command)
                Button("Copy") { Task { await model.copyToPasteboard(current()) } }
                Spacer()
                Button(role: .destructive) {
                    Task { await model.delete(snippet) }
                } label: { Text("Delete") }
            }
        }
        .padding(12)
        .onAppear(perform: loadFields)
        .onChange(of: snippet.id) { _, _ in loadFields() }
    }

    private func loadFields() {
        title = snippet.title
        content = snippet.content
        language = snippet.language ?? ""
        tagsText = snippet.tags.joined(separator: ", ")
    }

    private func current() -> Snippet {
        var edited = snippet
        edited.title = title
        edited.content = content
        edited.language = language.isEmpty ? nil : language
        edited.tags = tagsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return edited
    }

    private func save() {
        Task { await model.save(current()) }
    }
}
