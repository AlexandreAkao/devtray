import SwiftUI

public struct PreloadBusEnvironmentKey: EnvironmentKey {
    public static let defaultValue: PreloadBus = PreloadBus()
}

public extension EnvironmentValues {
    var preloadBus: PreloadBus {
        get { self[PreloadBusEnvironmentKey.self] }
        set { self[PreloadBusEnvironmentKey.self] = newValue }
    }
}
