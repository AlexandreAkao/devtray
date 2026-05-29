import DevTrayCore
import DevTrayUI
import RegexToolKit
import SwiftUI

public struct RegexToolView: View {
    @State private var pattern = ""
    @State private var input = ""
    @State private var template = ""
    @State private var caseInsensitive = false
    @State private var multiline = false
    @State private var dotAll = false
    @State private var matches: [RegexMatch] = []
    @State private var replaced = ""
    @State private var error: ToolError?

    /// preloadBus/smart-paste integration is intentionally omitted: regex has no clipboardMatch
    /// matcher. Add preloadBus support here if a matcher is introduced.
    public init() {}

    private var flags: RegexFlags {
        var f: RegexFlags = []
        if caseInsensitive { f.insert(.caseInsensitive) }
        if multiline { f.insert(.multiline) }
        if dotAll { f.insert(.dotMatchesLineSeparators) }
        return f
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Pattern", text: $pattern)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: pattern) { _, _ in recompute() }

            HStack {
                Toggle("i", isOn: $caseInsensitive).help("Case-insensitive")
                Toggle("m", isOn: $multiline).help("^$ match line boundaries")
                Toggle("s", isOn: $dotAll).help(". matches newlines")
            }
            .toggleStyle(.button)
            .onChange(of: flags.rawValue) { _, _ in recompute() }

            CodeEditor(text: $input, placeholder: "Test string", minHeight: 90)
                .onChange(of: input) { _, _ in recompute() }

            if let error {
                InlineErrorBanner(error: error)
            } else {
                Text("\(matches.count) match\(matches.count == 1 ? "" : "es")")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(matches.enumerated()), id: \.offset) { _, match in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(match.value).font(.system(.body, design: .monospaced))
                        ForEach(match.groups.dropFirst(), id: \.index) { group in
                            Text("  $\(group.index): \(group.value ?? "—")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()
            TextField("Replacement template ($1, $2…)", text: $template)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: template) { _, _ in recompute() }
            if !replaced.isEmpty {
                MonospaceOutput(replaced)
            }
        }
    }

    private func recompute() {
        guard !pattern.isEmpty else {
            matches = []; replaced = ""; error = nil; return
        }
        switch RegexEngine.evaluate(pattern: pattern, flags: flags, input: input) {
        case .success(let m): matches = m; error = nil
        case .failure(let e): matches = []; error = e
        }
        if error == nil, !template.isEmpty,
           case .success(let r) = RegexEngine.replace(pattern: pattern, flags: flags, input: input, template: template) {
            replaced = r
        } else {
            replaced = ""
        }
    }
}
