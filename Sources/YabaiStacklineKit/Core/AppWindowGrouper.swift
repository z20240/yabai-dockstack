/// Returns a single app's windows across all spaces, for the Dock preview popover.
public enum AppWindowGrouper {
    public static func windows(of app: String, in windows: [YabaiWindow]) -> [YabaiWindow] {
        windows.filter { $0.app == app }
            .sorted { ($0.space, $0.stackIndex, $0.id) < ($1.space, $1.stackIndex, $1.id) }
    }
}
