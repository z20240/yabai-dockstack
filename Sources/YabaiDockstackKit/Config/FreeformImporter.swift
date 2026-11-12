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

    /// True when the line starts with whitespace (inside an `if …; then` block or a
    /// function, i.e. conditional). Such lines are never commented out: they are not
    /// representable, and a then-block reduced to only a comment is a shell syntax error.
    public static func isIndented(_ line: String) -> Bool {
        line.first == " " || line.first == "\t"
    }

    public static func importSkhd(fileText: String, current: [ShortcutBinding],
                                  catalog: [ShortcutAction], scriptsDir: String) -> SkhdImportResult {
        var bindings = current
        func setBinding(_ id: String, _ hk: Hotkey) {
            if let i = bindings.firstIndex(where: { $0.actionID == id }) {
                bindings[i].enabled = true; bindings[i].hotkey = hk
            } else {
                bindings.append(ShortcutBinding(actionID: id, enabled: true, hotkey: hk))
            }
        }
        // Same first-match classification as the panel (FaithfulSkhd), over the whole
        // file: an action already bound earlier — including inside the managed region —
        // isn't represented by a later hand-written line, so that line stays as it is.
        let lines = fileText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let roles = FaithfulSkhd.classify(lines, catalog: catalog, scriptsDir: scriptsDir)
        var out: [String] = []
        var count = 0
        var inRegion = false
        for (line, role) in zip(lines, roles) {
            if ManagedRegion.isBeginMarker(line) { inRegion = true; out.append(line); continue }
            if ManagedRegion.isEndMarker(line)   { inRegion = false; out.append(line); continue }
            if !inRegion, case .binding(let id, let hk) = role {
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

            // Indented = conditional (if-block / function): never commented out.
            if isIndented(line) { out.append(line); continue }
            var imported = true
            if let (key, v) = YabaiConfigLine.parse(line) {
                switch (key, Int(v)) {
                case ("layout", _):
                    if let lay = YabaiSettings.Layout(rawValue: v), lay == .bsp || lay == .float { s.layout = lay }
                    else { imported = false }
                case ("top_padding", let n?):    s.topPadding = n
                case ("bottom_padding", let n?): s.bottomPadding = n
                case ("left_padding", let n?):   s.leftPadding = n
                case ("right_padding", let n?):  s.rightPadding = n
                case ("window_gap", let n?):     s.gap = n
                default: imported = false
                }
            } else if let r = YabaiRuleLine.parse(line) {
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
}
