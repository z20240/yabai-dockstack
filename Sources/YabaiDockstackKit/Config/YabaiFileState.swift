import Foundation

/// Whole-file view of a yabairc: what the file says, regardless of who wrote it.
public struct YabaiFileState: Equatable {
    public var layout: YabaiSettings.Layout?
    public var top, bottom, left, right, gap: Int?
    public var rules: [WindowRule]
    public var otherRules: [String]
    /// The file's layout word when the panel can't represent it (e.g. `stack`); nil otherwise.
    public var unrepresentedLayout: String?

    public init(layout: YabaiSettings.Layout? = nil, top: Int? = nil, bottom: Int? = nil,
                left: Int? = nil, right: Int? = nil, gap: Int? = nil,
                rules: [WindowRule] = [], otherRules: [String] = [], unrepresentedLayout: String? = nil) {
        self.layout = layout; self.top = top; self.bottom = bottom; self.left = left
        self.right = right; self.gap = gap; self.rules = rules; self.otherRules = otherRules
        self.unrepresentedLayout = unrepresentedLayout
    }

    public static func parse(_ text: String) -> YabaiFileState {
        var s = YabaiFileState()
        var layoutWord: String?
        var sawOff = false
        // Non-editable rule lines in file order; catch-alls are flagged so they can be
        // hidden when (and only when) they are what makes the layout Float.
        var other: [(line: String, catchAll: Bool)] = []
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "# dockstack:layout-off" { sawOff = true; continue }
            if line.isEmpty || line.hasPrefix("#") { continue }
            if YabaiRuleLine.isRuleAdd(line) {
                if let r = YabaiRuleLine.parse(line) {
                    if let i = s.rules.firstIndex(where: { $0.app == r.app }) { s.rules[i] = r }
                    else { s.rules.append(r) }
                } else {
                    other.append((line, YabaiRuleLine.isCatchAll(line)))
                }
                continue
            }
            guard let (key, val) = YabaiConfigLine.parse(line) else { continue }
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
        let sawCatchAll = other.contains { $0.catchAll }
        switch layoutWord {
        case "bsp": s.layout = .bsp
        case "float": s.layout = sawCatchAll ? .float : .off
        // No layout line: yabai's built-in `float`, which the catch-all makes Float;
        // without one it's left unset (shown as Off, yabai's built-in).
        case nil: s.layout = sawCatchAll ? .float : nil
        case let word?: s.layout = nil; s.unrepresentedLayout = word
        }
        if sawOff { s.layout = .off; s.unrepresentedLayout = nil }
        let hideCatchAll = s.layout == .float
        s.otherRules = other.filter { !($0.catchAll && hideCatchAll) }.map(\.line)
        return s
    }
}
