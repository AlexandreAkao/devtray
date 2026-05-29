import AppKit
import DevTrayCore
import DevTrayUI
import SwiftUI
import UUIDToolKit

public struct UUIDToolView: View {
    @Environment(\.preloadBus) private var preloadBus: PreloadBus
    @State private var format: IDFormat = .uuidV4
    @State private var count: Int = 1
    @State private var results: [String] = []
    @State private var error: ToolError?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Picker("Format", selection: $format) {
                    ForEach(IDFormat.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Stepper(value: $count, in: UUIDEngine.minCount ... UUIDEngine.maxCount) {
                    Text("Count: \(count)")
                        .monospacedDigit()
                }
                .frame(maxWidth: 160)
            }

            HStack {
                Button(action: generate) {
                    Label("Generate", systemImage: "sparkles")
                }
                .keyboardShortcut(.return, modifiers: [])

                if !results.isEmpty {
                    Button(action: copyAll) {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }
                }
                Spacer()
            }

            if let error {
                InlineErrorBanner(error: error)
            }

            if !results.isEmpty {
                ScrollView(.vertical) {
                    VStack(spacing: 6) {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, value in
                            MonospaceOutput(value, maxHeight: 44)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .onAppear {
            if results.isEmpty { generate() }
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
              payload.toolID == UUIDTool.id
        else { return }
        // No input field; just consume so the popover doesn't keep the pending state.
        _ = preloadBus.consume()
    }

    private func generate() {
        switch UUIDEngine.generate(format: format, count: count) {
        case .success(let ids):
            results = ids
            error = nil
        case .failure(let e):
            results = []
            error = e
        }
    }

    private func copyAll() {
        let joined = results.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(joined, forType: .string)
    }
}
