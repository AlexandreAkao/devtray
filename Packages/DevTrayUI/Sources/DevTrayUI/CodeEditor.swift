import AppKit
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
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            PlainTextView(text: $text)
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

private struct PlainTextView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let tv = scroll.documentView as! NSTextView

        tv.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.isRichText = false
        tv.usesFontPanel = false
        tv.allowsUndo = true
        tv.textContainerInset = NSSize(width: 4, height: 6)
        tv.drawsBackground = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true

        tv.delegate = context.coordinator
        tv.string = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context _: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        if tv.string != text {
            tv.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            self._text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text = tv.string
        }
    }
}
