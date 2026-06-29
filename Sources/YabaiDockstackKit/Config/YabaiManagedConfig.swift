import Foundation

public enum YabaiManagedConfig {
    public static func generate(_ s: YabaiSettings) -> String {
        var lines: [String] = []
        switch s.layout {
        case .bsp, .float: lines.append("yabai -m config layout \(s.layout.rawValue)")
        case .off: lines.append("# dockstack:layout-off")
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
        if !s.rules.isEmpty { lines.append("yabai -m rule --apply") }
        return lines.joined(separator: "\n")
    }

    public static func parse(_ body: String) -> YabaiSettings {
        var s = YabaiSettings.defaults
        s.rules = []
        var sawRule = false
        for raw in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line == "# dockstack:layout-off" { s.layout = .off; continue }
            if let v = value(line, key: "layout") { s.layout = YabaiSettings.Layout(rawValue: v) ?? s.layout }
            else if let v = intValue(line, key: "top_padding") { s.topPadding = v }
            else if let v = intValue(line, key: "bottom_padding") { s.bottomPadding = v }
            else if let v = intValue(line, key: "left_padding") { s.leftPadding = v }
            else if let v = intValue(line, key: "right_padding") { s.rightPadding = v }
            else if let v = intValue(line, key: "window_gap") { s.gap = v }
            else if let r = rule(line) { s.rules.append(r); sawRule = true }
        }
        _ = sawRule
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
