import SwiftUI
import DevTrayCore

struct FrequentToolChip: View {
    let tool: AnyTool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: tool.iconName)
                    .font(.caption2)
                Text(tool.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Frequent — \(tool.displayName)")
    }
}
