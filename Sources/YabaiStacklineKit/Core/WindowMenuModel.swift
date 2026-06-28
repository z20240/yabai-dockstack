/// Builds the display → space → windows tree shown in the menu bar.
public enum WindowMenuModel {
    public struct Entry: Equatable {
        public let id: Int
        public let pid: Int
        public let app: String
        public let title: String
        public let focused: Bool
    }
    public struct SpaceGroup: Equatable {
        public let space: Int
        public let windows: [Entry]
    }
    public struct DisplayGroup: Equatable {
        public let display: Int
        public let spaces: [SpaceGroup]
    }

    /// Group windows by display, then space; windows ordered by stack index then
    /// id. Displays and spaces are sorted ascending.
    public static func build(_ windows: [YabaiWindow]) -> [DisplayGroup] {
        let byDisplay = Dictionary(grouping: windows, by: { $0.display })
        return byDisplay.keys.sorted().map { display in
            let bySpace = Dictionary(grouping: byDisplay[display] ?? [], by: { $0.space })
            let spaces = bySpace.keys.sorted().map { space -> SpaceGroup in
                let wins = (bySpace[space] ?? [])
                    .sorted { ($0.stackIndex, $0.id) < ($1.stackIndex, $1.id) }
                    .map { Entry(id: $0.id, pid: $0.pid, app: $0.app, title: $0.title, focused: $0.hasFocus) }
                return SpaceGroup(space: space, windows: wins)
            }
            return DisplayGroup(display: display, spaces: spaces)
        }
    }
}
