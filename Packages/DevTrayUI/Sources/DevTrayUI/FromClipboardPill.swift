import SwiftUI

struct FromClipboardPill: View {
    var body: some View {
        Text("from clipboard")
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.4)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.15))
            )
            .foregroundStyle(Color.accentColor)
    }
}
