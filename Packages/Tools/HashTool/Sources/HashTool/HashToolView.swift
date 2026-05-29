import AppKit
import SwiftUI
import DevTrayCore
import DevTrayUI
import HashToolKit

public struct HashToolView: View {
    @Environment(\.preloadBus) private var preloadBus: PreloadBus
    @State private var input: String = ""
    @State private var fileName: String?
    @State private var md5: String = ""
    @State private var sha1: String = ""
    @State private var sha256: String = ""
    @State private var sha512: String = ""
    @State private var error: ToolError?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Choose file…") { chooseFile() }
                if let fileName {
                    Text(fileName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Button("Clear") { self.fileName = nil; recompute() }
                }
            }
            CodeEditor(text: $input, placeholder: "Text to hash", minHeight: 80)
                .onChange(of: input) { _, _ in recompute() }

            if let error {
                InlineErrorBanner(error: error)
            }

            if !md5.isEmpty {
                labeledRow("MD5", value: md5)
                labeledRow("SHA-1", value: sha1)
                labeledRow("SHA-256", value: sha256)
                labeledRow("SHA-512", value: sha512)
            }
        }
        .onReceive(preloadBus.$pending) { _ in
            applyPendingPreloadIfMatches()
        }
        .task {
            applyPendingPreloadIfMatches()
        }
    }

    private func applyPendingPreloadIfMatches() {
        guard let payload = preloadBus.pending,
              payload.toolID == HashTool.id,
              let text = payload.text
        else { return }
        input = text
        _ = preloadBus.consume()
    }

    @ViewBuilder
    private func labeledRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            MonospaceOutput(value, maxHeight: 60)
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            // Loads the whole file into memory; fine for dev-tool file sizes.
            let data = try Data(contentsOf: url)
            fileName = url.lastPathComponent
            hash(data)
        } catch {
            fileName = nil
            self.error = .invalidInput(reason: "Could not read \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func hash(_ data: Data) {
        func val(_ r: Result<String, ToolError>) -> String { (try? r.get()) ?? "" }
        md5 = val(HashEngine.md5(data: data)); sha1 = val(HashEngine.sha1(data: data))
        sha256 = val(HashEngine.sha256(data: data)); sha512 = val(HashEngine.sha512(data: data))
        error = data.isEmpty ? .invalidInput(reason: "File is empty") : nil
    }

    private func recompute() {
        fileName = nil
        guard !input.isEmpty else {
            md5 = ""; sha1 = ""; sha256 = ""; sha512 = ""
            error = nil
            return
        }
        switch HashEngine.md5(input) {
        case .success(let s): md5 = s
        case .failure(let e): error = e; md5 = ""; return
        }
        switch HashEngine.sha1(input) {
        case .success(let s): sha1 = s
        case .failure(let e): error = e; sha1 = ""; return
        }
        switch HashEngine.sha256(input) {
        case .success(let s): sha256 = s
        case .failure(let e): error = e; sha256 = ""; return
        }
        switch HashEngine.sha512(input) {
        case .success(let s): sha512 = s; error = nil
        case .failure(let e): error = e; sha512 = ""
        }
    }
}
