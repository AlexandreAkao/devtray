import AppKit
import ColorToolKit
import DevTrayCore
import DevTrayUI
import SwiftUI

public struct ColorToolView: View {
    @Environment(\.preloadBus) private var preloadBus: PreloadBus
    @State private var input = "#FF8800"
    @State private var value: ColorValue? = ColorValue(r: 255, g: 136, b: 0, a: 1)
    @State private var error: ToolError?

    public init() {}

    private var pickerColor: Binding<Color> {
        Binding(
            get: {
                guard let v = value else { return .clear }
                return Color(.sRGB, red: Double(v.r) / 255, green: Double(v.g) / 255, blue: Double(v.b) / 255, opacity: v.a)
            },
            set: { newColor in
                guard let ns = NSColor(newColor).usingColorSpace(.sRGB) else { return }
                let v = ColorValue(
                    r: Int((ns.redComponent * 255).rounded()),
                    g: Int((ns.greenComponent * 255).rounded()),
                    b: Int((ns.blueComponent * 255).rounded()),
                    a: Double(ns.alphaComponent))
                value = v
                input = v.hex
                error = nil
            }
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("#hex, rgb(), or hsl()", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: input) { _, _ in recompute() }
                ColorPicker("", selection: pickerColor, supportsOpacity: true)
                    .labelsHidden()
            }

            if let error {
                InlineErrorBanner(error: error)
            } else if let value {
                MonospaceOutput(value.hex)
                MonospaceOutput(value.rgbString)
                MonospaceOutput(value.hslString)
            }
        }
        .onReceive(preloadBus.$pending) { _ in applyPendingPreloadIfMatches() }
        .task { applyPendingPreloadIfMatches() }
    }

    private func applyPendingPreloadIfMatches() {
        guard let payload = preloadBus.pending, payload.toolID == ColorTool.id, let text = payload.text else { return }
        input = text
        recompute()
        _ = preloadBus.consume()
    }

    private func recompute() {
        switch ColorEngine.parse(input) {
        case .success(let v): value = v; error = nil
        case .failure(let e): value = nil; error = e
        }
    }
}
