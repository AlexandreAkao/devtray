import DevTrayCore
import SwiftUI

public struct LicenseTab: View {
    @Environment(\.licenseState) private var licenseState: LicenseState
    @Environment(\.licenseStore) private var licenseStore: LicenseStore
    @Environment(\.licenseClient) private var licenseClient: LicenseClient

    @State private var pasteField = ""
    @State private var status: TabStatus = .idle
    @State private var showDeactivateConfirm = false

    public init() {}

    public var body: some View {
        Form {
            Section("Status") { statusCard }
            Section("Activate a license") { activateSection }
            if case .licensed = licenseState {
                Section { deactivateButton }
            }
            Section { footerLinks }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 460)
        .onReceive(NotificationCenter.default.publisher(for: .selectLicenseTab)) { _ in
            // No-op here; the parent SettingsView observes the same notification to switch tabs.
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        switch licenseState {
        case .untrialed:
            label("Trial starting…", systemImage: "hourglass", tint: .secondary)
        case let .trialing(daysLeft):
            label("Trialing — \(daysLeft) day\(daysLeft == 1 ? "" : "s") left",
                  systemImage: "clock.badge",
                  tint: .orange)
        case .trialExpired:
            label("Trial expired", systemImage: "lock.fill", tint: .red)
        case let .licensed(claims):
            VStack(alignment: .leading, spacing: 4) {
                label("Licensed", systemImage: "checkmark.seal.fill", tint: .green)
                Text(claims.email).font(.callout).foregroundStyle(.secondary)
                Text("License #\(claims.licenseUUID.uuidString.prefix(8))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        case .revoked:
            label("License revoked", systemImage: "xmark.seal.fill", tint: .red)
        }
    }

    private func label(_ text: String, systemImage: String, tint: Color) -> some View {
        HStack { Image(systemName: systemImage).foregroundStyle(tint); Text(text) }
    }

    @ViewBuilder
    private var activateSection: some View {
        if case .licensed = licenseState {
            Text("This Mac is already activated. To switch licenses, deactivate first.")
                .font(.callout).foregroundStyle(.secondary)
        } else {
            TextField("Paste DT1-… key", text: $pasteField, axis: .vertical)
                .lineLimit(2 ... 4)
                .textFieldStyle(.roundedBorder)
                .font(.system(.callout, design: .monospaced))
            HStack {
                Button("Activate") { Task { await runActivate() } }
                    .disabled(pasteField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || status == .working)
                    .buttonStyle(.borderedProminent)
                if case .error(let msg) = status {
                    Text(msg).font(.caption).foregroundStyle(.red)
                }
                if status == .working { ProgressView().controlSize(.small) }
                Spacer()
            }
        }
    }

    private var deactivateButton: some View {
        Button("Deactivate this Mac", role: .destructive) {
            showDeactivateConfirm = true
        }
        .confirmationDialog("Deactivate this Mac?",
                            isPresented: $showDeactivateConfirm,
                            titleVisibility: .visible) {
            Button("Deactivate", role: .destructive) { Task { await runDeactivate() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This frees one of your 3 activation slots. You can re-activate by pasting the license key again.")
        }
    }

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: 6) {
            if case .licensed = licenseState {
                Text("Need to deactivate another Mac you can't reach? Email ")
                    + Text("[support@devtray.app](mailto:support@devtray.app)")
            } else {
                Link("Buy a license — $19", destination: PaywallView.buyURL)
                Text("All 13 tools and Spotlight stay free forever.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func runActivate() async {
        status = .working
        let key = pasteField.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let validator = try LicenseValidator()
            let claims = try validator.verify(key)
            let machineHash = try MachineIdentifier.hash(for: claims.licenseUUID)
            let resp = try await licenseClient.activate(licenseUUID: claims.licenseUUID,
                                                        machineHash: machineHash)
            guard resp.ok else { throw LicenseClientError.activationFailed(reason: "server_rejected") }
            try await licenseStore.storeLicense(key, claims: claims, machineHash: machineHash)
            pasteField = ""
            status = .ok
            // The parent app re-derives LicenseState from store on next tick.
            NotificationCenter.default.post(name: .licenseStateNeedsRefresh, object: nil)
        } catch let LicenseClientError.activationFailed(reason) {
            status = .error("Activation failed: \(reason)")
        } catch LicenseClientError.licenseNotFound {
            status = .error("Unknown license")
        } catch LicenseValidationError.invalidSignature {
            status = .error("Invalid license signature")
        } catch let err as LicenseValidationError {
            status = .error("License error: \(err)")
        } catch {
            status = .error("Couldn't reach the licensing server")
        }
    }

    private func runDeactivate() async {
        status = .working
        do {
            guard let stored = try await licenseStore.storedLicense() else { return }
            try await licenseClient.deactivate(licenseUUID: stored.claims.licenseUUID,
                                               machineHash: stored.machineHash)
            try await licenseStore.clearLicense()
            status = .ok
            NotificationCenter.default.post(name: .licenseStateNeedsRefresh, object: nil)
        } catch {
            status = .error("Couldn't reach the licensing server")
        }
    }
}

enum TabStatus: Equatable {
    case idle, working, ok, error(String)
}

public extension Notification.Name {
    static let licenseStateNeedsRefresh = Notification.Name("com.devtray.licenseStateNeedsRefresh")
}
