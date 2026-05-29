import CronToolKit
import DevTrayCore
import DevTrayUI
import SwiftUI

public struct CronToolView: View {
    @Environment(\.preloadBus) private var preloadBus: PreloadBus
    @State private var input = "0 9 * * 1-5"
    @State private var humanDesc = ""
    @State private var next: [Date] = []
    @State private var error: ToolError?

    public init() {}

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM yyyy HH:mm"
        return f
    }()

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("minute hour day-of-month month day-of-week", text: $input)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: input) { _, _ in recompute() }

            if let error {
                InlineErrorBanner(error: error)
            } else {
                Text(humanDesc).font(.callout)
                if !next.isEmpty {
                    Text("Next runs").font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(next.enumerated()), id: \.offset) { _, date in
                        Text(Self.formatter.string(from: date))
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
        .onReceive(preloadBus.$pending) { _ in applyPendingPreloadIfMatches() }
        .task { recompute(); applyPendingPreloadIfMatches() }
    }

    private func applyPendingPreloadIfMatches() {
        guard let payload = preloadBus.pending, payload.toolID == CronTool.id, let text = payload.text else { return }
        input = text
        recompute()
        _ = preloadBus.consume()
    }

    private func recompute() {
        switch CronEngine.parse(input) {
        case .success(let e):
            error = nil
            humanDesc = CronEngine.humanDescription(e)
            next = CronEngine.nextExecutions(e, from: .now, count: 5)
        case .failure(let e):
            error = e; humanDesc = ""; next = []
        }
    }
}
