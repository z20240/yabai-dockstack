import Foundation

/// Which windows a switcher trigger shows.
public enum SwitcherScope: String, Codable, CaseIterable {
    case allWindows, currentApp, currentSpace
}

/// One cell/row in the switcher panel.
public struct SwitcherItem: Equatable {
    public let id: Int
    public let pid: Int
    public let app: String
    public let title: String
    public let space: Int
    public let display: Int
    public let hasFocus: Bool

    public init(id: Int, pid: Int, app: String, title: String,
                space: Int, display: Int, hasFocus: Bool) {
        self.id = id; self.pid = pid; self.app = app; self.title = title
        self.space = space; self.display = display; self.hasFocus = hasFocus
    }
}

public enum SwitcherModel {
    /// Cross-space window list for the switcher: filter by scope + search query,
    /// then order by MRU. Windows never seen by the MRU follow in
    /// (space, stackIndex, id) order. The scope anchor is the focused window,
    /// falling back to the most recently used one (e.g. when the desktop has focus).
    public static func build(windows: [YabaiWindow], mru: [Int],
                             scope: SwitcherScope, query: String = "") -> [SwitcherItem] {
        let anchor = windows.first { $0.hasFocus }
            ?? mru.lazy.compactMap { id in windows.first { $0.id == id } }.first
        var pool = windows
        switch scope {
        case .allWindows:
            break
        case .currentApp:
            if let a = anchor { pool = pool.filter { $0.app == a.app } }
        case .currentSpace:
            if let a = anchor { pool = pool.filter { $0.space == a.space } }
            else { pool = pool.filter { $0.isVisible } }
        }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            pool = pool.filter { $0.app.lowercased().contains(q) || $0.title.lowercased().contains(q) }
        }
        var rank: [Int: Int] = [:]
        for (i, id) in mru.enumerated() where rank[id] == nil { rank[id] = i }
        let sorted = pool.sorted { a, b in
            switch (rank[a.id], rank[b.id]) {
            case let (ra?, rb?): return ra < rb
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return (a.space, a.stackIndex, a.id) < (b.space, b.stackIndex, b.id)
            }
        }
        return sorted.map {
            SwitcherItem(id: $0.id, pid: $0.pid, app: $0.app, title: $0.title,
                         space: $0.space, display: $0.display, hasFocus: $0.hasFocus)
        }
    }

    /// Where the selection starts: on the previous window (classic alt-tab)
    /// when the front item is the currently focused one; backward activation
    /// (shift held) starts from the far end.
    public static func initialIndex(count: Int, firstHasFocus: Bool, backward: Bool) -> Int {
        guard count > 1 else { return 0 }
        if backward { return count - 1 }
        return firstHasFocus ? 1 : 0
    }
}
