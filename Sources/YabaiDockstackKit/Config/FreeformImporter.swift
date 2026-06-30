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
}
