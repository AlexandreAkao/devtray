import SwiftUI
import DevTrayCore

public struct InlineErrorBanner: View {
    public let error: ToolError

    public init(error: ToolError) {
        self.error = error
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(error.errorDescription ?? "Unknown error")
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}
