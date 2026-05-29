import SwiftUI
import DevTrayCore
import DevTrayUI
import JWTToolKit

public struct JWTToolView: View {
    @Environment(\.preloadBus) private var preloadBus: PreloadBus
    @State private var input: String = ""
    @State private var decoded: DecodedJWT?
    @State private var error: ToolError?

    @State private var algorithm: JWTEngine.JWTAlgorithm = .hs256
    @State private var key: String = ""
    @State private var verifyResult: Bool?
    @State private var verifyError: ToolError?

    @State private var encHeader: String = #"{"alg":"HS256","typ":"JWT"}"#
    @State private var encClaims: String = #"{"sub":"1234567890"}"#
    @State private var encOutput: String = ""
    @State private var encError: ToolError?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                decodeSection
                Divider()
                signatureSection
                Divider()
                encodeSection
            }
            .padding(.bottom, 8)
        }
        .onReceive(preloadBus.$pending) { _ in applyPendingPreloadIfMatches() }
        .task { applyPendingPreloadIfMatches() }
    }

    private var decodeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste a JWT to decode")
                .font(.caption).foregroundStyle(.secondary)
            CodeEditor(text: $input, placeholder: "eyJhbGciOi...", minHeight: 90)
                .onChange(of: input) { _, v in recompute(v) }
            if let error { InlineErrorBanner(error: error) }
            if let decoded {
                Label("Header", systemImage: "h.square").font(.caption).foregroundStyle(.secondary)
                MonospaceOutput(decoded.headerJSON, maxHeight: 120)
                Label("Payload", systemImage: "p.square").font(.caption).foregroundStyle(.secondary)
                MonospaceOutput(decoded.payloadJSON, maxHeight: 120)
            }
        }
    }

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Algorithm", selection: $algorithm) {
                ForEach(JWTEngine.JWTAlgorithm.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: algorithm) { _, _ in
                verifyResult = nil; verifyError = nil
                encOutput = ""; encError = nil
            }
            CodeEditor(
                text: $key,
                placeholder: algorithm == .hs256 ? "HMAC secret" : "-----BEGIN RSA PUBLIC KEY-----",
                minHeight: algorithm == .hs256 ? 36 : 90)
            Button("Verify signature") { runVerify() }
                .disabled(input.isEmpty || key.isEmpty)
            if let verifyResult {
                Label(verifyResult ? "Signature valid" : "Signature INVALID",
                      systemImage: verifyResult ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(verifyResult ? .green : .red)
                    .font(.callout)
            }
            if let verifyError { InlineErrorBanner(error: verifyError) }
        }
    }

    private var encodeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Encode (\(algorithm.rawValue))").font(.caption).foregroundStyle(.secondary)
            Text("Header").font(.caption2).foregroundStyle(.secondary)
            CodeEditor(text: $encHeader, placeholder: "{...}", minHeight: 44)
            Text("Claims").font(.caption2).foregroundStyle(.secondary)
            CodeEditor(text: $encClaims, placeholder: "{...}", minHeight: 60)
            Text(algorithm == .hs256 ? "Signed with the secret above." : "Signed with the PRIVATE PEM above (never leaves the app).")
                .font(.caption2).foregroundStyle(.tertiary)
            Button("Generate token") { runEncode() }.disabled(key.isEmpty)
            if let encError { InlineErrorBanner(error: encError) }
            if !encOutput.isEmpty { MonospaceOutput(encOutput, maxHeight: 90) }
        }
    }

    private func applyPendingPreloadIfMatches() {
        guard let payload = preloadBus.pending, payload.toolID == JWTTool.id, let text = payload.text else { return }
        input = text
        _ = preloadBus.consume()
    }

    private func recompute(_ raw: String) {
        verifyResult = nil; verifyError = nil
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            decoded = nil; error = nil; return
        }
        switch JWTEngine.decode(raw) {
        case .success(let d): decoded = d; error = nil
        case .failure(let e): decoded = nil; error = e
        }
    }

    private func runVerify() {
        switch JWTEngine.verify(token: input, algorithm: algorithm, key: key) {
        case .success(let ok): verifyResult = ok; verifyError = nil
        case .failure(let e): verifyResult = nil; verifyError = e
        }
    }

    private func runEncode() {
        switch JWTEngine.encode(headerJSON: encHeader, claimsJSON: encClaims, algorithm: algorithm, key: key) {
        case .success(let token): encOutput = token; encError = nil
        case .failure(let e): encOutput = ""; encError = e
        }
    }
}
