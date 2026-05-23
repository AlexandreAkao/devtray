import SwiftUI
import DevTrayCore

struct SpotlightRow: View {
    let result: SpotlightResult
    let tool: AnyTool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tool.iconName)
                .frame(width: 22, height: 22)
                .foregroundStyle(.secondary)
            Text(tool.displayName)
                .font(.body)
            Spacer()
            if result.fromClipboard {
                FromClipboardPill()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
