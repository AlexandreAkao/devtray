import SwiftUI
import Combine
import DevTrayCore

@MainActor
public final class SpotlightViewModel: ObservableObject {
    @Published public private(set) var rows: [(result: SpotlightResult, tool: AnyTool)] = []
    @Published public var query: String = ""
    @Published public var selectedID: ToolID?

    private let ranker: SpotlightRanker
    private let registry: ToolRegistry
    private var rerankTask: Task<Void, Never>?
    public private(set) var clipboard: String?

    public init(ranker: SpotlightRanker, registry: ToolRegistry) {
        self.ranker = ranker
        self.registry = registry
    }

    public func onOpen(clipboard: String?) {
        self.clipboard = clipboard
        self.query = ""
        scheduleRerank(debounceMillis: 0)
    }

    public func onQueryChanged() {
        scheduleRerank(debounceMillis: 80)
    }

    public func tool(for id: ToolID) -> AnyTool? {
        registry.find(byID: id)
    }

    public func moveSelection(by delta: Int) {
        guard !rows.isEmpty else { selectedID = nil; return }
        let currentIndex = rows.firstIndex(where: { $0.result.toolID == selectedID }) ?? 0
        let newIndex = (currentIndex + delta + rows.count) % rows.count
        selectedID = rows[newIndex].result.toolID
    }

    private func scheduleRerank(debounceMillis: UInt64) {
        rerankTask?.cancel()
        rerankTask = Task { [weak self] in
            guard let self else { return }
            if debounceMillis > 0 {
                try? await Task.sleep(nanoseconds: debounceMillis * 1_000_000)
                if Task.isCancelled { return }
            }
            let snapshotQuery = self.query
            let snapshotClipboard = self.clipboard
            let results = await self.ranker.rank(
                query: snapshotQuery,
                clipboard: snapshotClipboard,
                limit: 8
            )
            if Task.isCancelled { return }
            let rows = results.compactMap { r -> (result: SpotlightResult, tool: AnyTool)? in
                guard let t = self.registry.find(byID: r.toolID) else { return nil }
                return (result: r, tool: t)
            }
            self.rows = rows
            if let first = rows.first,
               !rows.contains(where: { $0.result.toolID == self.selectedID })
            {
                self.selectedID = first.result.toolID
            }
        }
    }
}
