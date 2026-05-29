import Combine
import Foundation

@MainActor
public final class ToolPreferences: ObservableObject {
    @Published public private(set) var disabledIDs: Set<String>
    private let defaults: UserDefaults
    private let storageKey = "DevTray.disabledToolIDs"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.disabledIDs = Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    public func isEnabled(_ id: ToolID) -> Bool { !disabledIDs.contains(id.rawValue) }

    public func setEnabled(_ enabled: Bool, for id: ToolID) {
        if enabled { disabledIDs.remove(id.rawValue) } else { disabledIDs.insert(id.rawValue) }
        defaults.set(Array(disabledIDs), forKey: storageKey)
    }

    public func enabled(_ tools: [AnyTool]) -> [AnyTool] {
        tools.filter { isEnabled($0.id) }
    }
}
