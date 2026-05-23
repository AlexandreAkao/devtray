import SwiftUI
import DevTrayCore
import DevTrayUI
import TimestampToolKit

public struct TimestampToolView: View {
    @Environment(\.preloadBus) private var preloadBus: PreloadBus
    @State private var input: String = ""
    @State private var breakdown: TimestampBreakdown?
    @State private var error: ToolError?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Epoch (s/ms) or ISO 8601", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: input) { _, _ in recompute() }

                Button(action: useNow) {
                    Label("Now", systemImage: "clock.arrow.circlepath")
                }
            }

            if let error {
                InlineErrorBanner(error: error)
            }

            if let b = breakdown {
                labeledRow("Epoch (s)", value: String(b.epochSeconds))
                labeledRow("Epoch (ms)", value: String(b.epochMillis))
                labeledRow("ISO 8601 (UTC)", value: b.isoUTC)
                labeledRow("ISO 8601 (Local)", value: b.isoLocal)
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
              payload.toolID == TimestampTool.id,
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
            MonospaceOutput(value, maxHeight: 44)
        }
    }

    private func recompute() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            breakdown = nil
            error = nil
            return
        }
        switch TimestampEngine.parse(input) {
        case .success(let b):
            breakdown = b
            error = nil
        case .failure(let e):
            breakdown = nil
            error = e
        }
    }

    private func useNow() {
        let b = TimestampEngine.now()
        input = String(b.epochSeconds)
        breakdown = b
        error = nil
    }
}
