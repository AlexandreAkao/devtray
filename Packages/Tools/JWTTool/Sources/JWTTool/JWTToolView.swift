import SwiftUI
import DevTrayCore
import DevTrayUI
import JWTToolKit

public struct JWTToolView: View {
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
            jsonBlock(decoded.headerJSON)

            Label("Payload", systemImage: "p.square")
                .font(.caption)
                .foregroundStyle(.secondary)
            jsonBlock(decoded.payloadJSON)
        }
    }

    private func jsonBlock(_ text: String) -> some View {
        ScrollView(.vertical) {
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .frame(maxHeight: 140)
        .background(Color(nsColor: .textBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 6))
    }
}
