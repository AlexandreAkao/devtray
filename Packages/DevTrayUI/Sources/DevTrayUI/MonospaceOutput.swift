import AppKit
import SwiftUI

public struct MonospaceOutput: View {
    private let text: String
    private let maxHeight: CGFloat
    @State private var copied = false

    public init(_ text: String, maxHeight: CGFloat = 280) {
        self.text = text
        self.maxHeight = maxHeight
    }

    public var body: some View {
        ScrollView(.vertical) {
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .frame(maxHeight: maxHeight)
        .background(Color(nsColor: .textBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .topTrailing) {
            Button(action: copy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(copied ? .green : .secondary)
                    .padding(6)
                    .background(.thickMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.trailing, 18)
            .help(copied ? "Copied" : "Copy to clipboard")
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.25)) { copied = false }
        }
    }
}
