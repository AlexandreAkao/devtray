import DevTrayCore
import DevTrayUI
import SwiftUI
import YAMLToolKit

public struct YAMLToolView: View {
    enum Direction: String, CaseIterable, Identifiable {
        case yamlToJSON = "YAML → JSON"
        case jsonToYAML = "JSON → YAML"
        var id: String { rawValue }
    }

    @State private var input = ""
    @State private var output = ""
    @State private var direction: Direction = .yamlToJSON
    @State private var error: ToolError?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Direction", selection: $direction) {
                ForEach(Direction.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: direction) { _, _ in recompute() }

            CodeEditor(
                text: $input,
                placeholder: direction == .yamlToJSON ? "YAML" : "JSON",
                minHeight: 110
            )
            .onChange(of: input) { _, _ in recompute() }

            if let error {
                InlineErrorBanner(error: error)
            } else if !output.isEmpty {
                MonospaceOutput(output)
            }
        }
    }

    private func recompute() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = ""; error = nil; return
        }
        let result: Result<String, ToolError>
        switch direction {
        case .yamlToJSON: result = YAMLEngine.yamlToJSON(input)
        case .jsonToYAML: result = YAMLEngine.jsonToYAML(input)
        }
        switch result {
        case .success(let s): output = s; error = nil
        case .failure(let e): output = ""; error = e
        }
    }
}
