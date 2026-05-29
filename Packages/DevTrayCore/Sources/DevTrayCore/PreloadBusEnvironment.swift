import SwiftUI

private struct PreloadBusEnvironmentKey: EnvironmentKey {
    static let defaultValue: PreloadBus = .init()
}

public extension EnvironmentValues {
    var preloadBus: PreloadBus {
        get { self[PreloadBusEnvironmentKey.self] }
        set { self[PreloadBusEnvironmentKey.self] = newValue }
    }
}
