import SwiftUI
import DevTrayCore

public extension View {
    /// Gates the modified view behind LicenseState (from @Environment).
    ///
    /// State → behavior:
    ///   .untrialed, .trialing, .licensed → content unchanged
    ///   .trialExpired, .revoked          → content dimmed (opacity 0.4),
    ///                                       non-interactive, with a centered
    ///                                       "🔒 Buy to unlock" pill;
    ///                                       tap anywhere → PaywallView sheet.
    func paywalled() -> some View {
        modifier(PaywalledModifier())
    }
}

struct PaywalledModifier: ViewModifier {
    @Environment(\.licenseState) private var licenseState: LicenseState
    @State private var showingPaywall = false

    func body(content: Content) -> some View {
        if licenseState.isGated {
            content
                .opacity(0.4)
                .allowsHitTesting(false)
                .overlay(
                    Button {
                        showingPaywall = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                            Text("Buy to unlock")
                        }
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                )
                .sheet(isPresented: $showingPaywall) {
                    PaywallView()
                }
        } else {
            content
        }
    }
}
