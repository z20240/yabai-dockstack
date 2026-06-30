import Foundation

public enum FreeformImporter {
    /// Collapse script-directory differences so equivalent commands compare equal:
    /// any "<path>/scripts/" prefix and "${SCRIPTS}/" become the token "@S@".
    public static func normalizeCommand(_ cmd: String) -> String {
        var s = cmd.replacingOccurrences(of: "${SCRIPTS}/", with: "@S@")
        s = s.replacingOccurrences(of: #"\S*/scripts/"#, with: "@S@", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// Lenient single-line skhd `keysym : command` parse. nil for comments, blanks,
    /// directives (.load/.shell/.blacklist), mode declarations (::name), line
    /// continuations (trailing backslash), or an unparseable keysym / empty command.
    public static func parseSkhdLine(_ line: String) -> (hotkey: Hotkey, command: String)? {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty || t.hasPrefix("#") || t.hasPrefix("::") || t.hasPrefix(".") { return nil }
        if t.hasSuffix("\\") { return nil }
        guard let colon = t.firstIndex(of: ":") else { return nil }
        let lhs = String(t[..<colon]).trimmingCharacters(in: .whitespaces)
        let rhs = String(t[t.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        guard !rhs.isEmpty, let hk = Hotkey.parse(lhs) else { return nil }
        return (hk, rhs)
    }

    public struct SkhdImportResult: Equatable {
        public var bindings: [ShortcutBinding]
        public var newText: String
        public var importedCount: Int
    }

    public static func importSkhd(fileText: String, current: [ShortcutBinding],
                                  catalog: [ShortcutAction], scriptsDir: String) -> SkhdImportResult {
        var cmdToID: [String: String] = [:]
        for a in catalog {
            let resolved = a.command.replacingOccurrences(of: "${SCRIPTS}", with: scriptsDir)
            cmdToID[normalizeCommand(resolved)] = a.id
        }
        var bindings = current
        func setBinding(_ id: String, _ hk: Hotkey) {
            if let i = bindings.firstIndex(where: { $0.actionID == id }) {
                bindings[i].enabled = true; bindings[i].hotkey = hk
            } else {
                bindings.append(ShortcutBinding(actionID: id, enabled: true, hotkey: hk))
            }
        }
        var out: [String] = []
        var count = 0
        var inRegion = false
        for raw in fileText.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if ManagedRegion.isBeginMarker(line) { inRegion = true; out.append(line); continue }
            if ManagedRegion.isEndMarker(line)   { inRegion = false; out.append(line); continue }
            if inRegion { out.append(line); continue }
            if let (hk, cmd) = parseSkhdLine(line), let id = cmdToID[normalizeCommand(cmd)] {
                setBinding(id, hk)
                out.append("# [yabai-dockstack imported] " + line)
                count += 1
            } else {
                out.append(line)
            }
        }
        return SkhdImportResult(bindings: bindings, newText: out.joined(separator: "\n"), importedCount: count)
    }

    public struct YabaiImportResult: Equatable {
        public var settings: YabaiSettings
        public var newText: String
        public var importedCount: Int
    }

    public static func importYabai(fileText: String, current: YabaiSettings) -> YabaiImportResult {
        var s = current
        var rulesByApp: [String: WindowRule] = [:]
        var order: [String] = []
        for r in s.rules { rulesByApp[r.app] = r; order.append(r.app) }

        var out: [String] = []
        var count = 0
        var inRegion = false
        for raw in fileText.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if ManagedRegion.isBeginMarker(line) { inRegion = true; out.append(line); continue }
            if ManagedRegion.isEndMarker(line)   { inRegion = false; out.append(line); continue }
            if inRegion { out.append(line); continue }

            let t = line.trimmingCharacters(in: .whitespaces)
            var imported = true
            if let v = configValue(t, "layout"), let lay = YabaiSettings.Layout(rawValue: v), lay != .off {
                s.layout = lay
            } else if let v = intConfig(t, "top_padding")    { s.topPadding = v }
            else if let v = intConfig(t, "bottom_padding")   { s.bottomPadding = v }
            else if let v = intConfig(t, "left_padding")     { s.leftPadding = v }
            else if let v = intConfig(t, "right_padding")    { s.rightPadding = v }
            else if let v = intConfig(t, "window_gap")       { s.gap = v }
            else if let r = parseRule(t) {
                if rulesByApp[r.app] == nil { order.append(r.app) }
                rulesByApp[r.app] = r
            } else {
                imported = false
            }
            if imported { out.append("# [yabai-dockstack imported] " + line); count += 1 }
            else        { out.append(line) }
        }
        s.rules = order.compactMap { rulesByApp[$0] }
        return YabaiImportResult(settings: s, newText: out.joined(separator: "\n"), importedCount: count)
    }

    // "yabai -m config <key> <value>" -> value
    private static func configValue(_ line: String, _ key: String) -> String? {
        let prefix = "yabai -m config \(key) "
        guard line.hasPrefix(prefix) else { return nil }
        return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
    }

    private static func intConfig(_ line: String, _ key: String) -> Int? {
        configValue(line, key).flatMap { Int($0) }
    }

    // yabai -m rule --add app="X" … manage=off|on …  (requires explicit manage=, skips ".*")
    private static func parseRule(_ line: String) -> WindowRule? {
        guard line.hasPrefix("yabai -m rule --add app=\"") else { return nil }
        guard let s = line.range(of: "app=\""),
              let e = line.range(of: "\"", range: s.upperBound..<line.endIndex) else { return nil }
        let app = String(line[s.upperBound..<e.lowerBound])
        if app == ".*" { return nil }
        if line.contains("manage=on")  { return WindowRule(app: app, mode: .manage) }
        if line.contains("manage=off") { return WindowRule(app: app, mode: .float) }
        return nil
    }
}
