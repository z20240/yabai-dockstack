import Foundation

/// Most-recently-used window ordering for the switcher. Pure data structure:
/// the runtime feeds it focus changes on every refresh; `ids` drives
/// SwitcherModel's sort so alt-tab lands on the previously used window.
public struct MRUOrder: Equatable {
    /// Window ids, most recent first.
    public private(set) var ids: [Int]

    public init(ids: [Int] = []) { self.ids = ids }

    /// Move `id` to the front (inserting if new).
    public mutating func touch(_ id: Int) {
        if ids.first == id { return }
        ids.removeAll { $0 == id }
        ids.insert(id, at: 0)
    }

    /// Drop ids of windows that no longer exist.
    public mutating func prune(keeping existing: Set<Int>) {
        ids.removeAll { !existing.contains($0) }
    }
}
