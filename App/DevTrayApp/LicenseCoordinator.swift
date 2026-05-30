import Combine
import DevTrayCore
import DevTrayUI
import Foundation

/// Owns the periodic heartbeat Timer and exposes a published LicenseState.
/// Subscribes to `.licenseStateNeedsRefresh` notifications (posted by LicenseTab on activate/deactivate).
@MainActor
final class LicenseCoordinator: ObservableObject {
    @Published private(set) var state: LicenseState = .untrialed

    private let store: LicenseStore
    private let tracker: TrialTracker
    private let client: LicenseClient
    private let validator: LicenseValidator?
    private var heartbeatTimer: Timer?
    private var refreshObserver: NSObjectProtocol?

    init(store: LicenseStore, tracker: TrialTracker, client: LicenseClient) {
        self.store = store
        self.tracker = tracker
        self.client = client
        self.validator = try? LicenseValidator()

        refreshObserver = NotificationCenter.default.addObserver(
            forName: .licenseStateNeedsRefresh, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    deinit {
        if let o = refreshObserver { NotificationCenter.default.removeObserver(o) }
        heartbeatTimer?.invalidate()
    }

    /// Call on app launch. Bootstraps trial, computes state, schedules heartbeat.
    func bootstrap() async {
        try? await tracker.recordLastSeen()
        await refresh()
        await sendHeartbeatIfLicensed()
        scheduleWeeklyHeartbeat()
    }

    /// Recompute LicenseState from Keychain + TrialTracker. Posts to @Published `state`.
    func refresh() async {
        // 1. If a license is stored and re-verifies, we're .licensed.
        if let stored = try? await store.storedLicense(),
           let validator,
           (try? validator.verify(stored.jwt)) != nil {
            state = .licensed(claims: stored.claims)
            return
        }
        // 2. Otherwise trial logic.
        let setback = await (try? tracker.detectClockSetback()) ?? false
        if setback { state = .trialExpired; return }
        guard let status = try? await tracker.currentStatus() else {
            state = .untrialed
            return
        }
        state = status.expired ? .trialExpired : .trialing(daysLeft: status.daysLeft)
    }

    /// Handles `devtray://activate?license=DT1-…` URL.
    func handleActivationURL(_ url: URL) async {
        guard url.scheme == "devtray", url.host == "activate" else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let key = comps?.queryItems?.first(where: { $0.name == "license" })?.value else { return }
        await activate(rawKey: key)
    }

    func activate(rawKey: String) async {
        guard let validator else { return }
        guard let claims = try? validator.verify(rawKey) else { return }
        guard let machineHash = try? MachineIdentifier.hash(for: claims.licenseUUID) else { return }
        guard let resp = try? await client.activate(licenseUUID: claims.licenseUUID, machineHash: machineHash),
              resp.ok else { return }
        try? await store.storeLicense(rawKey, claims: claims, machineHash: machineHash)
        await refresh()
    }

    // MARK: - Heartbeat

    private func sendHeartbeatIfLicensed() async {
        guard case .licensed = state,
              let stored = try? await store.storedLicense() else { return }
        let resp = await client.heartbeat(licenseUUID: stored.claims.licenseUUID,
                                          machineHash: stored.machineHash)
        if resp.revoked {
            try? await store.clearLicense()
            await refresh()
        }
    }

    private func scheduleWeeklyHeartbeat() {
        heartbeatTimer?.invalidate()
        let weekly: TimeInterval = 7 * 86_400
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: weekly, repeats: true) { [weak self] _ in
            Task { await self?.sendHeartbeatIfLicensed() }
        }
    }
}
