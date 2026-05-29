import DevTrayCore
import DevTrayUI
import SwiftUI
import URLToolKit

public struct URLToolView: View {
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

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in recompute() }

            CodeEditor(
                text: $input,
                placeholder: mode == .encode ? "Plain text or URL" : "Percent-encoded text",
                minHeight: 100
            )
            .onChange(of: input) { _, _ in recompute() }

            if let error {
                InlineErrorBanner(error: error)
            }

            if !output.isEmpty {
                MonospaceOutput(output)
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
              payload.toolID == URLTool.id,
              let text = payload.text
        else { return }
        input = text
        _ = preloadBus.consume()
    }

    private func recompute() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = ""
            error = nil
            return
        }
        let result: Result<String, ToolError>
        switch mode {
        case .encode: result = URLEngine.encode(input)
        case .decode: result = URLEngine.decode(input)
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
