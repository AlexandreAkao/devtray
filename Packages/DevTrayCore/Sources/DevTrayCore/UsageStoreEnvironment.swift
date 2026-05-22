import SwiftUI

private struct UsageStoreKey: EnvironmentKey {
    static let defaultValue: any UsageStore = InMemoryUsageStore()
}

public extension EnvironmentValues {
    var usageStore: any UsageStore {
        get { self[UsageStoreKey.self] }
        set { self[UsageStoreKey.self] = newValue }
    }
}
