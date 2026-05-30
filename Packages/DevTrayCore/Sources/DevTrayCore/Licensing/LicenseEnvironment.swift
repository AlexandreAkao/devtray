import Foundation
import SwiftUI

// MARK: - LicenseState env

private struct LicenseStateKey: EnvironmentKey {
    static let defaultValue: LicenseState = .untrialed
}

public extension EnvironmentValues {
    var licenseState: LicenseState {
        get { self[LicenseStateKey.self] }
        set { self[LicenseStateKey.self] = newValue }
    }
}

// MARK: - LicenseStore env

private struct LicenseStoreKey: EnvironmentKey {
    static let defaultValue: LicenseStore = LicenseStore(keychain: InMemoryKeychain())
}

public extension EnvironmentValues {
    var licenseStore: LicenseStore {
        get { self[LicenseStoreKey.self] }
        set { self[LicenseStoreKey.self] = newValue }
    }
}

// MARK: - LicenseClient env

private struct LicenseClientKey: EnvironmentKey {
    static let defaultValue: LicenseClient = LicenseClient()
}

public extension EnvironmentValues {
    var licenseClient: LicenseClient {
        get { self[LicenseClientKey.self] }
        set { self[LicenseClientKey.self] = newValue }
    }
}

// MARK: - TrialTracker env

private struct TrialTrackerKey: EnvironmentKey {
    static let defaultValue: TrialTracker = TrialTracker(keychain: InMemoryKeychain())
}

public extension EnvironmentValues {
    var trialTracker: TrialTracker {
        get { self[TrialTrackerKey.self] }
        set { self[TrialTrackerKey.self] = newValue }
    }
}
