import Foundation

/// One rule as reported by `yabai -m rule --list`.
public struct LiveRule: Equatable {
    public var windowRule: WindowRule?
    public var summary: String
    public var isCatchAll: Bool

    public init(windowRule: WindowRule?, summary: String, isCatchAll: Bool) {
        self.windowRule = windowRule; self.summary = summary; self.isCatchAll = isCatchAll
    }

    public static func decodeList(_ data: Data) -> [LiveRule] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.map(decode)
    }

    private static func str(_ d: [String: Any], _ k: String) -> String { (d[k] as? String) ?? "" }
    private static func isNull(_ d: [String: Any], _ k: String) -> Bool { d[k] == nil || d[k] is NSNull }
    private static func num(_ d: [String: Any], _ k: String) -> Double { (d[k] as? NSNumber)?.doubleValue ?? 0 }

    private static func decode(_ d: [String: Any]) -> LiveRule {
        let app = str(d, "app")
        let manage: Bool? = isNull(d, "manage") ? nil : (d["manage"] as? Bool)
        let sub = str(d, "sub-layer")

        var parts: [String] = []
        if !app.isEmpty { parts.append("app=\"\(app)\"") }
        for k in ["title", "role", "subrole", "label", "scratchpad"] where !str(d, k).isEmpty {
            parts.append("\(k)=\"\(str(d, k))\"")
        }
        for k in ["display", "space"] where num(d, k) != 0 { parts.append("\(k)=\(Int(num(d, k)))") }
        if num(d, "opacity") != 0 { parts.append("opacity=\(num(d, "opacity"))") }
        if let m = manage { parts.append("manage=\(m ? "on" : "off")") }
        for k in ["sticky", "mouse_follows_focus", "native-fullscreen"] where !isNull(d, k) {
            if let b = d[k] as? Bool { parts.append("\(k)=\(b ? "on" : "off")") }
        }
        if !sub.isEmpty && sub != "normal" { parts.append("sub-layer=\(sub)") }
        let grid = str(d, "grid")
        if !grid.isEmpty && grid != "0:0:0:0:0:0" { parts.append("grid=\(grid)") }
        if (d["one-shot"] as? Bool) == true { parts.append("one-shot=on") }
        let summary = parts.joined(separator: " ")

        // No condition or effect other than app / manage / sub-layer.
        let onlyAppManageSub = ["title", "role", "subrole", "label", "scratchpad"].allSatisfy { str(d, $0).isEmpty }
            && num(d, "display") == 0 && num(d, "space") == 0 && num(d, "opacity") == 0
            && isNull(d, "sticky") && isNull(d, "mouse_follows_focus") && isNull(d, "native-fullscreen")
            && (grid.isEmpty || grid == "0:0:0:0:0:0")
            && (d["one-shot"] as? Bool) != true
        // The Float layout's catch-all: `app=".*" manage=off` (any sub-layer), nothing else.
        let catchAll = onlyAppManageSub && app == YabaiManagedConfig.floatCatchAllApp && manage == false
        let clean = onlyAppManageSub && !app.isEmpty && app != YabaiManagedConfig.floatCatchAllApp
        var rule: WindowRule?
        if clean, let m = manage {
            // Same sub-layer strictness as YabaiRuleLine.
            let normalSub = sub.isEmpty || sub == "normal" || sub == "unset"
            if normalSub { rule = WindowRule(app: app, mode: m ? .manage : .float) }
            else if sub == "above" && !m { rule = WindowRule(app: app, mode: .pin) }
        }
        return LiveRule(windowRule: rule, summary: summary, isCatchAll: catchAll)
    }
}

/// Snapshot of what yabai is running now.
public struct YabaiLiveState: Equatable {
    public var layout: String?
    public var top, bottom, left, right, gap: Int?
    public var rules: [LiveRule]

    public init(layout: String? = nil, top: Int? = nil, bottom: Int? = nil, left: Int? = nil,
                right: Int? = nil, gap: Int? = nil, rules: [LiveRule] = []) {
        self.layout = layout; self.top = top; self.bottom = bottom; self.left = left
        self.right = right; self.gap = gap; self.rules = rules
    }
}
