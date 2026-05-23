import SwiftUI
import DevTrayCore
import DevTrayUI
import JWTToolKit

public struct JWTToolView: View {
    @Environment(\.preloadBus) private var preloadBus: PreloadBus
    @State private var input: String = ""
    @State private var decoded: DecodedJWT?
    @State private var error: ToolError?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paste a JWT to decode")
                .font(.caption)
                .foregroundStyle(.secondary)

            CodeEditor(
                text: $input,
                placeholder: "eyJhbGciOi...",
                minHeight: 100
            )
            .onChange(of: input) { _, newValue in
                recompute(newValue)
            }

            if let error {
                InlineErrorBanner(error: error)
            }

            if let decoded {
                decodedView(decoded)
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
              payload.toolID == JWTTool.id,
              let text = payload.text
        else { return }
        input = text
        _ = preloadBus.consume()
    }

    private func recompute(_ raw: String) {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            decoded = nil
            error = nil
            return
        }
        switch JWTEngine.decode(raw) {
        case .success(let d):
            decoded = d
            error = nil
        case .failure(let e):
            decoded = nil
            error = e
        }
    }

    private func decodedView(_ decoded: DecodedJWT) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Header", systemImage: "h.square")
                .font(.caption)
                .foregroundStyle(.secondary)
            MonospaceOutput(decoded.headerJSON, maxHeight: 140)

            Label("Payload", systemImage: "p.square")
                .font(.caption)
                .foregroundStyle(.secondary)
            MonospaceOutput(decoded.payloadJSON, maxHeight: 140)
        }
    }
}
