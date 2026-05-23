import Combine

/// Lightweight pub-sub for clipboard preload from Spotlight to the popover.
///
/// **Threading contract:** all calls happen on the main actor in practice
/// (Spotlight controller and SwiftUI views), but the class itself is not
/// annotated `@MainActor` so it can be used as a stored property and an
/// `EnvironmentKey.defaultValue` without ceremony. SwiftUI's `@Published`
/// subscription model handles UI updates.
public final class PreloadBus: ObservableObject {
    @Published public private(set) var pending: PreloadPayload?

    public init() {}

    public func send(_ payload: PreloadPayload) {
        pending = payload
    }

    @discardableResult
    public func consume() -> PreloadPayload? {
        let current = pending
        pending = nil
        return current
    }
}
