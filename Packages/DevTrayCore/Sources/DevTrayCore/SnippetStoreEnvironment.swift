import SwiftUI

private struct SnippetStoreKey: EnvironmentKey {
    static let defaultValue: any SnippetStore = InMemorySnippetStore()
}

public extension EnvironmentValues {
    var snippetStore: any SnippetStore {
        get { self[SnippetStoreKey.self] }
        set { self[SnippetStoreKey.self] = newValue }
    }
}
