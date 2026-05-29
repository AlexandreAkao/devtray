import DevTrayCore
import DevTrayUI
import DiffToolKit
import SwiftUI

public struct DiffToolView: View {
    enum ViewMode: String, CaseIterable, Identifiable {
        case sideBySide = "Side-by-side"
        case unified = "Unified"
        var id: String { rawValue }
    }

    @State private var left = ""
    @State private var right = ""
    @State private var mode: ViewMode = .sideBySide
    @State private var rows: [DiffRow] = []
    @State private var hunks: [DiffHunk] = []

    public init() {}

    private func recompute() {
        rows = DiffEngine.diffLines(left, right)
        hunks = DiffEngine.unifiedHunks(left, right)
    }

    private func color(_ kind: DiffRowKind) -> Color {
        switch kind {
        case .equal: return .clear
        case .insert: return .green.opacity(0.18)
        case .delete: return .red.opacity(0.18)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                CodeEditor(text: $left, placeholder: "Original", minHeight: 90)
                CodeEditor(text: $right, placeholder: "Changed", minHeight: 90)
            }
            Picker("View", selection: $mode) {
                ForEach(ViewMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if mode == .sideBySide {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            Text(row.text.isEmpty ? " " : row.text)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .background(color(row.kind))
                        }
                    } else {
                        ForEach(Array(hunks.enumerated()), id: \.offset) { _, hunk in
                            Text(hunk.header)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            ForEach(Array(hunk.rows.enumerated()), id: \.offset) { _, row in
                                let sign = row.kind == .insert ? "+" : (row.kind == .delete ? "-" : " ")
                                Text("\(sign) \(row.text)")
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                                    .background(color(row.kind))
                            }
                        }
                    }
                }
            }
        }
        .task { recompute() }
        .onChange(of: left) { _, _ in recompute() }
        .onChange(of: right) { _, _ in recompute() }
    }
}
