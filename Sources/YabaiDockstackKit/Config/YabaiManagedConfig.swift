import Foundation

public enum YabaiManagedConfig {
    /// Synthetic catch-all rule used only for the `.float` mode: a global
    /// `manage=off` (emitted last, so it wins) sets every window's `is-floating`
    /// flag true, so the mode-aware floating shortcuts (`focusWindow.sh` etc.) take
    /// their floating branch. Marked synthetic so `parse` never surfaces it as a
    /// user rule. `.off`, by contrast, just floats the layout and leaves windows
    /// untouched (native feel).
    static let floatCatchAllApp = ".*"

    public static func generate(_ s: YabaiSettings) -> String {
        var lines: [String] = []
        switch s.layout {
        case .bsp, .float:
            lines.append("yabai -m config layout \(s.layout.rawValue)")
        case .off:
            // No real yabai "off" layout exists; just float the space and leave
            // windows untouched — yabai stops tiling but doesn't flag them floating.
            lines.append("# dockstack:layout-off")
            lines.append("yabai -m config layout float")
        }
        lines.append("yabai -m config top_padding \(s.topPadding)")
        lines.append("yabai -m config bottom_padding \(s.bottomPadding)")
        lines.append("yabai -m config left_padding \(s.leftPadding)")
        lines.append("yabai -m config right_padding \(s.rightPadding)")
        lines.append("yabai -m config window_gap \(s.gap)")
        for r in s.rules {
            let manage = r.mode == .float ? "off" : "on"
            lines.append("yabai -m rule --add app=\"\(r.app)\" manage=\(manage) sub-layer=normal")
        }
        if s.layout == .float {
            lines.append("yabai -m rule --add app=\"\(floatCatchAllApp)\" manage=off sub-layer=normal")
        }
        if !s.rules.isEmpty || s.layout == .float { lines.append("yabai -m rule --apply") }
        return lines.joined(separator: "\n")
    }

    public static func parse(_ body: String) -> YabaiSettings {
        var s = YabaiSettings.defaults
        s.rules = []
        var sawOff = false
        for raw in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line == "# dockstack:layout-off" { sawOff = true; continue }
            if let v = value(line, key: "layout") { s.layout = YabaiSettings.Layout(rawValue: v) ?? s.layout }
            else if let v = intValue(line, key: "top_padding") { s.topPadding = v }
            else if let v = intValue(line, key: "bottom_padding") { s.bottomPadding = v }
            else if let v = intValue(line, key: "left_padding") { s.leftPadding = v }
            else if let v = intValue(line, key: "right_padding") { s.rightPadding = v }
            else if let v = intValue(line, key: "window_gap") { s.gap = v }
            else if let r = rule(line) {
                // Skip the synthetic float-mode catch-all; it is not a user rule.
                if r.app == floatCatchAllApp { continue }
                s.rules.append(r)
            }
        }
        // The sentinel wins over the float line emitted alongside it.
        if sawOff { s.layout = .off }
        return s
    }

    // "yabai -m config <key> <value>" -> value
    private static func value(_ line: String, key: String) -> String? {
        let prefix = "yabai -m config \(key) "
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }
    private static func intValue(_ line: String, key: String) -> Int? {
        value(line, key: key).flatMap { Int($0) }
    }
    // yabai -m rule --add app="X" manage=off sub-layer=normal
    private static func rule(_ line: String) -> WindowRule? {
        guard line.hasPrefix("yabai -m rule --add app=\"") else { return nil }
        guard let appStart = line.range(of: "app=\""),
              let appEnd = line.range(of: "\"", range: appStart.upperBound..<line.endIndex) else { return nil }
        let app = String(line[appStart.upperBound..<appEnd.lowerBound])
        let mode: WindowRule.Mode = line.contains("manage=on") ? .manage : .float
        return WindowRule(app: app, mode: mode)
    }
}
