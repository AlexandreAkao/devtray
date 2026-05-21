import SwiftUI

public struct CodeEditor: View {
    @Binding private var text: String
    private let placeholder: String
    private let minHeight: CGFloat

    public init(text: Binding<String>, placeholder: String = "", minHeight: CGFloat = 100) {
        self._text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 0)
                .padding(.vertical, 4)
        }
        .frame(minHeight: minHeight)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
