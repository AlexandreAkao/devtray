import AppKit
import SwiftUI
import DevTrayCore
import DevTrayUI
import Base64ToolKit

public struct Base64ToolView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case encode = "Encode"
        case decode = "Decode"
        var id: String { rawValue }
    }

    @Environment(\.preloadBus) private var preloadBus: PreloadBus
    @State private var input: String = ""
    @State private var output: String = ""
    @State private var error: ToolError?
    @State private var mode: Mode = .encode
    @State private var fileName: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if mode == .encode {
                HStack {
                    Button("Choose file…") { chooseFile() }
                    if let fileName {
                        Text(fileName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }

            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in recompute() }

            CodeEditor(
                text: $input,
                placeholder: mode == .encode ? "Plain text" : "Base64",
                minHeight: 100
            )
            .onChange(of: input) { _, _ in recompute() }

            if let error {
                InlineErrorBanner(error: error)
            }

            if !output.isEmpty {
                if output.count > 20_000 {
                    HStack {
                        Text("\(output.count) chars").font(.caption).foregroundStyle(.secondary)
                        Button("Copy output") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(output, forType: .string)
                        }
                    }
                    MonospaceOutput(String(output.prefix(20_000)) + "\n… (truncated; use Copy)", maxHeight: 160)
                } else {
                    MonospaceOutput(output)
                }
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
              payload.toolID == Base64Tool.id,
              let text = payload.text
        else { return }
        input = text
        _ = preloadBus.consume()
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
            output = Base64Engine.encode(data)
            error = nil
        } catch {
            fileName = nil
            output = ""
            self.error = .invalidInput(reason: "Could not read \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func recompute() {
        fileName = nil
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = ""
            error = nil
            return
        }
        let result: Result<String, ToolError>
        switch mode {
        case .encode: result = Base64Engine.encode(input)
        case .decode: result = Base64Engine.decode(input)
        }
        switch result {
        case .success(let s):
            output = s
            error = nil
        case .failure(let e):
            output = ""
            error = e
        }
    }
}
