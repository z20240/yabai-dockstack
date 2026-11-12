import Foundation

/// Strict parser for `yabai -m rule --add ...` lines. Only rules the Settings panel
/// can represent faithfully (app + manage, optional sub-layer) are recognised.
public enum YabaiRuleLine {
    private static let prefix = "yabai -m rule --add"

    public static func isRuleAdd(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix(prefix) else { return false }
        let rest = t.dropFirst(prefix.count)
        return rest.isEmpty || rest.first == " " || rest.first == "\t"
    }

    public static func parse(_ line: String) -> WindowRule? {
        guard isRuleAdd(line) else { return nil }
        let t = line.trimmingCharacters(in: .whitespaces)
        var kv: [String: String] = [:]
        guard let toks = tokenize(String(t.dropFirst(prefix.count))) else { return nil }
        for tok in toks {
            guard let eq = tok.firstIndex(of: "=") else { return nil }
            let key = String(tok[..<eq])
            guard ["app", "manage", "sub-layer"].contains(key), kv[key] == nil else { return nil }
            kv[key] = String(tok[tok.index(after: eq)...])
        }
        guard let app = kv["app"], !app.isEmpty, app != ".*", let manage = kv["manage"] else { return nil }
        let sub = kv["sub-layer"]
        switch (manage, sub) {
        case ("on", nil), ("on", "normal"): return WindowRule(app: app, mode: .manage)
        case ("off", nil), ("off", "normal"): return WindowRule(app: app, mode: .float)
        case ("off", "above"): return WindowRule(app: app, mode: .pin)
        default: return nil
        }
    }

    /// The Float layout's catch-all: `app=".*" manage=off`, optionally `sub-layer=…`, and
    /// no other condition (a `title=…` etc. makes it an ordinary rule).
    public static func isCatchAll(_ line: String) -> Bool {
        guard isRuleAdd(line) else { return false }
        let t = line.trimmingCharacters(in: .whitespaces)
        guard let toks = tokenize(String(t.dropFirst(prefix.count))) else { return false }
        var kv: [String: String] = [:]
        for tok in toks {
            guard let eq = tok.firstIndex(of: "=") else { return false }
            let key = String(tok[..<eq])
            guard ["app", "manage", "sub-layer"].contains(key), kv[key] == nil else { return false }
            kv[key] = String(tok[tok.index(after: eq)...])
        }
        return kv["app"] == YabaiManagedConfig.floatCatchAllApp && kv["manage"] == "off"
    }

    /// Whitespace-split; double quotes group (and are removed).
    private static func tokenize(_ s: String) -> [String]? {
        var toks: [String] = [], cur = "", inQ = false, has = false
        for c in s {
            if c == "\"" { inQ.toggle(); has = true }
            else if (c == " " || c == "\t") && !inQ {
                if has { toks.append(cur); cur = ""; has = false }
            } else { cur.append(c); has = true }
        }
        if inQ { return nil }
        if has { toks.append(cur) }
        return toks
    }
}
