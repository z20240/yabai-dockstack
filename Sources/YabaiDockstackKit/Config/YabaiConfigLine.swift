import Foundation

/// The one classifier for `yabai -m config <key> <value>` lines, shared by the
/// whole-file view (`YabaiFileState`) and the importer (`FreeformImporter`), so both
/// agree on which lines set a value.
public enum YabaiConfigLine {
    /// `(key, value)` for a global `yabai -m config <key> <value>` line; nil for anything
    /// else (comments, `--space` / `--display` scoped settings, queries, extra words).
    /// Leading/inner whitespace (spaces or tabs) is free; a trailing ` # …` comment is ignored.
    public static func parse(_ line: String) -> (key: String, value: String)? {
        var body = line.trimmingCharacters(in: .whitespaces)
        if let c = body.range(of: "[ \\t]#", options: .regularExpression) {
            body = String(body[..<c.lowerBound])
        }
        let toks = body.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard toks.count == 5, toks[0] == "yabai", toks[1] == "-m", toks[2] == "config",
              !toks[3].hasPrefix("-") else { return nil }
        return (toks[3], toks[4])
    }
}
