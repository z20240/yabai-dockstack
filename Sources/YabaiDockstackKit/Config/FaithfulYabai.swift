import Foundation

public enum YabaiField: String, CaseIterable { case layout, top, bottom, left, right, gap }

public struct FieldDiff: Equatable {
    public var live: String
    public var file: String
    public var autoPadding: Bool
    public init(live: String, file: String, autoPadding: Bool) {
        self.live = live; self.file = file; self.autoPadding = autoPadding
    }
}

public enum RuleDiff: Equatable { case liveOnly, fileOnly, modeDiffers(file: WindowRule.Mode) }

public struct FaithfulYabaiView: Equatable {
    public var settings: YabaiSettings
    public var otherRules: [String]
    public var fieldDiffs: [YabaiField: FieldDiff]
    public var ruleDiffs: [String: RuleDiff]
    public var liveAvailable: Bool
}

public enum FaithfulYabai {
    public static func compose(live: YabaiLiveState?, file: YabaiFileState,
                               autoPaddingOriginal: Paddings?) -> FaithfulYabaiView {
        let d = YabaiSettings.defaults
        guard let live else {
            let s = YabaiSettings(layout: file.layout ?? d.layout, topPadding: file.top ?? d.topPadding,
                                  bottomPadding: file.bottom ?? d.bottomPadding,
                                  leftPadding: file.left ?? d.leftPadding, rightPadding: file.right ?? d.rightPadding,
                                  gap: file.gap ?? d.gap, rules: file.rules)
            return FaithfulYabaiView(settings: s, otherRules: file.otherRules, fieldDiffs: [:],
                                     ruleDiffs: [:], liveAvailable: false)
        }

        let layout: YabaiSettings.Layout
        switch live.layout {
        case "bsp": layout = .bsp
        case "float": layout = live.rules.contains(where: \.isCatchAll) ? .float : .off
        default: layout = file.layout ?? d.layout
        }
        let top = autoPaddingOriginal?.top ?? live.top ?? file.top ?? d.topPadding
        let left = autoPaddingOriginal?.left ?? live.left ?? file.left ?? d.leftPadding
        let right = autoPaddingOriginal?.right ?? live.right ?? file.right ?? d.rightPadding
        let bottom = live.bottom ?? file.bottom ?? d.bottomPadding
        let gap = live.gap ?? file.gap ?? d.gap

        var diffs: [YabaiField: FieldDiff] = [:]
        let auto = autoPaddingOriginal != nil
        func cmp(_ f: YabaiField, shown: Int, file: Int?, autoPad: Bool) {
            if let file, file != shown {
                diffs[f] = FieldDiff(live: String(shown), file: String(file), autoPadding: autoPad)
            }
        }
        if let fl = file.layout, fl != layout {
            diffs[.layout] = FieldDiff(live: layout.rawValue, file: fl.rawValue, autoPadding: false)
        }
        cmp(.top, shown: top, file: file.top, autoPad: auto)
        cmp(.left, shown: left, file: file.left, autoPad: auto)
        cmp(.right, shown: right, file: file.right, autoPad: auto)
        cmp(.bottom, shown: bottom, file: file.bottom, autoPad: false)
        cmp(.gap, shown: gap, file: file.gap, autoPad: false)

        var rules: [WindowRule] = []
        for lr in live.rules {
            guard let r = lr.windowRule else { continue }
            if let i = rules.firstIndex(where: { $0.app == r.app }) { rules[i] = r } else { rules.append(r) }
        }
        let liveApps = Set(rules.map(\.app))
        var ruleDiffs: [String: RuleDiff] = [:]
        let fileByApp = Dictionary(file.rules.map { ($0.app, $0.mode) }, uniquingKeysWith: { $1 })
        for r in rules {
            if let fm = fileByApp[r.app] {
                if fm != r.mode { ruleDiffs[r.app] = .modeDiffers(file: fm) }
            } else {
                ruleDiffs[r.app] = .liveOnly
            }
        }
        for fr in file.rules where !liveApps.contains(fr.app) {
            rules.append(fr)
            ruleDiffs[fr.app] = .fileOnly
        }
        let other = live.rules.filter { $0.windowRule == nil && !$0.isCatchAll }.map(\.summary)
        let s = YabaiSettings(layout: layout, topPadding: top, bottomPadding: bottom, leftPadding: left,
                              rightPadding: right, gap: gap, rules: rules)
        return FaithfulYabaiView(settings: s, otherRules: other, fieldDiffs: diffs,
                                 ruleDiffs: ruleDiffs, liveAvailable: true)
    }
}
