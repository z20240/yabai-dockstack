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
}
