import DevTrayCore
import SwiftUI

public struct TrialBanner: View {
    @Environment(\.licenseState) private var licenseState: LicenseState

    public init() {}

    public var body: some View {
        if case let .trialing(daysLeft) = licenseState {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge")
                Text(daysLeftCopy(daysLeft))
                    .font(.callout)
                Spacer()
                Link("Buy License", destination: PaywallView.buyURL)
                    .font(.callout.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.yellow.opacity(0.15))
            .overlay(Rectangle().frame(height: 0.5).foregroundStyle(.separator), alignment: .bottom)
            .accessibilityIdentifier("TrialBanner")
        }
    }

    private func daysLeftCopy(_ daysLeft: Int) -> String {
        switch daysLeft {
        case 0: return "DevTray trial — last day"
        case 1: return "DevTray trial — 1 day left"
        default: return "DevTray trial — \(daysLeft) days left"
        }
    }
}
