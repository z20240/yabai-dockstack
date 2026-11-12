import Foundation

/// One window inside a space card of the search switcher.
public struct SpaceTile: Equatable {
    public let item: SwitcherItem
    /// Window width / height, for the aspect-aware tiling.
    public let aspect: Double
    /// Matches the search query; non-matching tiles are dimmed, not removed.
    public let matches: Bool
}

/// One space in the search switcher (PR #4's Spaces View look).
public struct SpaceCard: Equatable {
    public let space: Int
    public let display: Int
    public let name: String
    public let isVisible: Bool
    public let hasFocus: Bool
    /// Native-fullscreen spaces are listed (their windows can be found) but
    /// take no drops and can't be swapped.
    public let isFullscreen: Bool
    public let tiles: [SpaceTile]
}

public enum SpacesSwitcherModel {
    /// Every space in (display, index) order, empty and fullscreen ones too.
    /// Tiles follow yabai's (stack index, id) order; items without a window in
    /// `windows` are dropped. `matching`: ids that pass the search query.
    public static func build(items: [SwitcherItem], windows: [YabaiWindow], spaces: [SpaceInfo],
                             labels: [Int: String], matching: Set<Int>) -> [SpaceCard] {
        let byID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return spaces.sorted { ($0.display, $0.index) < ($1.display, $1.index) }.map { sp in
            let tiles = items.compactMap { it -> (SpaceTile, YabaiWindow)? in
                guard it.space == sp.index, let w = byID[it.id] else { return nil }
                let aspect = w.frame.h > 0 ? max(w.frame.w / w.frame.h, 0.1) : 1
                return (SpaceTile(item: it, aspect: aspect, matches: matching.contains(it.id)), w)
            }
            .sorted { ($0.1.stackIndex, $0.1.id) < ($1.1.stackIndex, $1.1.id) }
            .map(\.0)
            let label = labels[sp.index] ?? ""
            return SpaceCard(space: sp.index, display: sp.display,
                             name: label.isEmpty ? "Space \(sp.index)" : label,
                             isVisible: sp.isVisible, hasFocus: sp.hasFocus,
                             isFullscreen: sp.isNativeFullscreen, tiles: tiles)
        }
    }

    /// Stand-in spaces read off the windows' own space / display fields, for
    /// before (or instead of) a successful `query --spaces`. A cold first
    /// open then shows real, selectable tiles instead of an empty panel, and
    /// the search switcher keeps working if the spaces query fails. Spaces
    /// without windows and fullscreen flags are unknown until the real query.
    public static func spacesFromWindows(_ windows: [YabaiWindow]) -> [SpaceInfo] {
        Dictionary(grouping: windows.filter { $0.space > 0 }, by: \.space)
            .map { space, ws in
                SpaceInfo(index: space, display: ws[0].display,
                          isVisible: ws.contains(where: \.isVisible),
                          hasFocus: ws.contains(where: \.hasFocus))
            }
            .sorted { $0.index < $1.index }
    }

    /// Keyboard order: matching tiles, card by card.
    public static func selectable(_ cards: [SpaceCard]) -> [SwitcherItem] {
        cards.flatMap { $0.tiles.filter(\.matches).map(\.item) }
    }
}
