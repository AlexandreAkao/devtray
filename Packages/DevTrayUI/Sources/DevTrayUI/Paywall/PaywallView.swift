import DevTrayCore
import SwiftUI

public struct PaywallView: View {
    @Environment(\.licenseState) private var licenseState: LicenseState
    @Environment(\.dismiss) private var dismiss

    /// External URL the "Buy License" CTA opens.
    public static let buyURL = URL(string: "https://api.devtray.app/buy")!

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.top, 24)

            Text(headline)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(subhead)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            featureGrid
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                Link(destination: Self.buyURL) {
                    Text("Buy License — $19")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Activate existing license…") {
                    openLicenseTab()
                    dismiss()
                }
                .buttonStyle(.borderless)

                if case .trialing = licenseState {
                    Button("Continue trial") { dismiss() }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 480)
    }

    private var headline: String {
        switch licenseState {
        case .trialExpired: return "Your trial has ended"
        case .revoked: return "Your license is no longer active"
        default: return "DevTray needs a license"
        }
    }

    private var subhead: String {
        "All 13 tools and Spotlight stay free forever. A license unlocks Snippets save/edit and the Tools preferences pane."
    }

    private var featureGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            featureRow("All 13 tools", free: true, licensed: true)
            featureRow("Spotlight + smart paste", free: true, licensed: true)
            featureRow("Auto-update via Sparkle", free: true, licensed: true)
            featureRow("Save / edit / delete snippets", free: false, licensed: true)
            featureRow("Settings → Tools toggles", free: false, licensed: true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func featureRow(_ label: String, free: Bool, licensed: Bool) -> some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            check(free).help("Free / trial expired").frame(width: 60)
            check(licensed).help("Licensed").frame(width: 60)
        }
    }

    private func check(_ on: Bool) -> some View {
        Image(systemName: on ? "checkmark.circle.fill" : "minus.circle")
            .foregroundStyle(on ? .green : .secondary)
    }

    /// Opens the Settings window and switches to the License tab. SwiftUI on macOS 14+ exposes
    /// `SettingsLink` for entry but no API to switch the selected tab from outside — we post a
    /// NotificationCenter event that LicenseTab listens for (see LicenseTab.swift).
    private func openLicenseTab() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NotificationCenter.default.post(name: .selectLicenseTab, object: nil)
    }
}

public extension Notification.Name {
    static let selectLicenseTab = Notification.Name("com.devtray.selectLicenseTab")
}
