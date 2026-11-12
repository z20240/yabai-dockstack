import Foundation

/// Whole-file view of a yabairc: what the file says, regardless of who wrote it.
public struct YabaiFileState: Equatable {
    public var layout: YabaiSettings.Layout?
    public var top, bottom, left, right, gap: Int?
    public var rules: [WindowRule]
    public var otherRules: [String]

    public init(layout: YabaiSettings.Layout? = nil, top: Int? = nil, bottom: Int? = nil,
                left: Int? = nil, right: Int? = nil, gap: Int? = nil,
                rules: [WindowRule] = [], otherRules: [String] = []) {
        self.layout = layout; self.top = top; self.bottom = bottom; self.left = left
        self.right = right; self.gap = gap; self.rules = rules; self.otherRules = otherRules
    }

    private static let configPrefix = "yabai -m config"

    public static func parse(_ text: String) -> YabaiFileState {
        var s = YabaiFileState()
        var layoutWord: String?
        var sawCatchAll = false, sawOff = false
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "# dockstack:layout-off" { sawOff = true; continue }
            if line.isEmpty || line.hasPrefix("#") { continue }
            if YabaiRuleLine.isRuleAdd(line) {
                if let r = YabaiRuleLine.parse(line) {
                    if let i = s.rules.firstIndex(where: { $0.app == r.app }) { s.rules[i] = r }
                    else { s.rules.append(r) }
                } else if isCatchAll(line) {
                    sawCatchAll = true
                } else {
                    s.otherRules.append(line)
                }
                continue
            }
            guard line.hasPrefix(configPrefix) else { continue }
            var body = String(line.dropFirst(configPrefix.count))
            if let c = body.range(of: "[ \\t]#", options: .regularExpression) { body = String(body[..<c.lowerBound]) }
            let toks = body.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard toks.count == 2 else { continue }
            let key = toks[0], val = toks[1]
            switch key {
            case "layout": layoutWord = val
            case "top_padding": s.top = Int(val)
            case "bottom_padding": s.bottom = Int(val)
            case "left_padding": s.left = Int(val)
            case "right_padding": s.right = Int(val)
            case "window_gap": s.gap = Int(val)
            default: break
            }
        }
        switch layoutWord {
        case "bsp": s.layout = .bsp
        case "float": s.layout = sawCatchAll ? .float : .off
        default: s.layout = nil
        }
        if sawOff { s.layout = .off }
        return s
    }

    /// `rule --add app=".*" manage=off` (extra keys tolerated); YabaiRuleLine rejects `.*`.
    private static func isCatchAll(_ line: String) -> Bool {
        let toks = line.replacingOccurrences(of: "\"", with: "")
            .split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        return toks.contains("app=\(YabaiManagedConfig.floatCatchAllApp)") && toks.contains("manage=off")
    }
}
