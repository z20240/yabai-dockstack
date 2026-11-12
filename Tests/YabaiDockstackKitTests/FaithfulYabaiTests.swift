import XCTest
@testable import YabaiDockstackKit

final class FaithfulYabaiTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let n = (name as NSString).deletingPathExtension
        let url = Bundle.module.url(forResource: n, withExtension: "json", subdirectory: "Fixtures")!
        return try Data(contentsOf: url)
    }

    func testFileStateLastWinsAndRegionIncluded() {
        let f = YabaiFileState.parse("yabai -m config window_gap 6\n# yabai -m config window_gap 99\n# >>> yabai-dockstack:managed BEGIN\nyabai -m config window_gap 8\n# <<< yabai-dockstack:managed END")
        XCTAssertEqual(f.gap, 8)
    }
    func testTrailingCommentStripped() {
        XCTAssertEqual(YabaiFileState.parse("yabai -m config window_gap 6 # tight").gap, 6)
        XCTAssertEqual(YabaiFileState.parse("yabai -m config window_gap 6\t# tight").gap, 6)
    }
    func testShellVariableIsUnknownNotZero() {
        XCTAssertNil(YabaiFileState.parse("yabai -m config window_gap $GAP").gap)
        XCTAssertNil(YabaiFileState.parse("yabai -m config window_gap 6\nyabai -m config window_gap $GAP").gap)
    }
    func testFileLayoutFloatWithoutCatchAllIsOff() {
        XCTAssertEqual(YabaiFileState.parse("yabai -m config layout float").layout, .off)
        XCTAssertEqual(YabaiFileState.parse("yabai -m config layout float\nyabai -m rule --add app=\".*\" manage=off").layout, .float)
        XCTAssertEqual(YabaiFileState.parse("yabai -m config layout bsp\n# dockstack:layout-off").layout, .off)
    }
    func testCatchAllNeverListedAndOtherRules() {
        let f = YabaiFileState.parse("yabai -m rule --add app=\".*\" manage=off\nyabai -m rule --add app=\"Finder\" title=\"Copy\" manage=off\nyabai -m rule --add app=\"A\" manage=off\nyabai -m rule --add app=\"A\" manage=on")
        XCTAssertEqual(f.rules, [WindowRule(app: "A", mode: .manage)])
        XCTAssertEqual(f.otherRules, ["yabai -m rule --add app=\"Finder\" title=\"Copy\" manage=off"])
    }
    func testLiveRuleDecode() throws {
        let rules = LiveRule.decodeList(try fixture("yabai-rules.json"))
        XCTAssertEqual(rules.compactMap(\.windowRule), [WindowRule(app: "Finder", mode: .float), WindowRule(app: "IINA", mode: .pin)])
        XCTAssertEqual(rules.filter(\.isCatchAll).count, 1)
        XCTAssertTrue(rules.contains { $0.windowRule == nil && !$0.isCatchAll && $0.summary.contains(#"title="Copy""#) })
    }
    func testLiveRuleSubLayerStrictness() {
        func rule(_ manage: String, _ sub: String) -> WindowRule? {
            let j = #"[{"app":"X","title":"","role":"","subrole":"","label":"","scratchpad":"","display":0,"space":0,"opacity":0.0,"manage":\#(manage),"sticky":null,"mouse_follows_focus":null,"sub-layer":"\#(sub)","native-fullscreen":null,"grid":"0:0:0:0:0:0","one-shot":false}]"#
            return LiveRule.decodeList(Data(j.utf8)).first?.windowRule
        }
        XCTAssertEqual(rule("true", "normal"), WindowRule(app: "X", mode: .manage))
        XCTAssertEqual(rule("false", ""), WindowRule(app: "X", mode: .float))
        XCTAssertEqual(rule("false", "above"), WindowRule(app: "X", mode: .pin))
        XCTAssertNil(rule("true", "above"))
        XCTAssertNil(rule("false", "below"))
    }
    func testComposeLiveWinsAndDiffs() {
        let file = YabaiFileState.parse("yabai -m config window_gap 6\nyabai -m rule --add app=\"Arc\" manage=off")
        let live = YabaiLiveState(layout: "bsp", top: 12, bottom: 12, left: 12, right: 12, gap: 10,
                                  rules: [LiveRule(windowRule: WindowRule(app: "Raycast", mode: .float), summary: "", isCatchAll: false)])
        let v = FaithfulYabai.compose(live: live, file: file, autoPaddingOriginal: nil)
        XCTAssertEqual(v.settings.gap, 10)
        XCTAssertEqual(v.fieldDiffs[.gap], FieldDiff(live: "10", file: "6", autoPadding: false))
        XCTAssertNil(v.fieldDiffs[.top])
        XCTAssertEqual(v.settings.rules.map(\.app), ["Raycast", "Arc"])
        XCTAssertEqual(v.ruleDiffs["Raycast"], .liveOnly); XCTAssertEqual(v.ruleDiffs["Arc"], .fileOnly)
        XCTAssertTrue(v.liveAvailable)
    }
    func testModeDiffersAndLayoutDiff() {
        let file = YabaiFileState.parse("yabai -m config layout float\nyabai -m rule --add app=\"A\" manage=on")
        let live = YabaiLiveState(layout: "bsp", rules: [LiveRule(windowRule: WindowRule(app: "A", mode: .float), summary: "", isCatchAll: false)])
        let v = FaithfulYabai.compose(live: live, file: file, autoPaddingOriginal: nil)
        XCTAssertEqual(v.ruleDiffs["A"], .modeDiffers(file: .manage))
        XCTAssertEqual(v.fieldDiffs[.layout], FieldDiff(live: "bsp", file: "off", autoPadding: false))
    }
    func testAutoPaddingShowsUserOriginal() {
        let file = YabaiFileState.parse("yabai -m config left_padding 12")
        let live = YabaiLiveState(layout: "bsp", top: 40, bottom: 0, left: 50, right: 50, gap: 0, rules: [])
        let v = FaithfulYabai.compose(live: live, file: file, autoPaddingOriginal: Paddings(left: 12, right: 12, top: 12))
        XCTAssertEqual(v.settings.leftPadding, 12); XCTAssertNil(v.fieldDiffs[.left])
        let f2 = YabaiFileState.parse("yabai -m config left_padding 20")
        let v2 = FaithfulYabai.compose(live: live, file: f2, autoPaddingOriginal: Paddings(left: 12, right: 12, top: 12))
        XCTAssertEqual(v2.fieldDiffs[.left], FieldDiff(live: "12", file: "20", autoPadding: true))
    }
    func testNoLiveFallsBackToFileWithoutDiffs() {
        let v = FaithfulYabai.compose(live: nil, file: YabaiFileState.parse("yabai -m config window_gap 6"), autoPaddingOriginal: nil)
        XCTAssertEqual(v.settings.gap, 6); XCTAssertTrue(v.fieldDiffs.isEmpty); XCTAssertFalse(v.liveAvailable)
        XCTAssertEqual(v.settings.topPadding, 0)
    }

    // MARK: - Final review fixes

    /// I3: with nothing from yabai or the file, show yabai's own built-in defaults.
    func testNoLiveFallsBackToYabaiBuiltInDefaults() {
        let v = FaithfulYabai.compose(live: nil, file: YabaiFileState.parse("yabai -m rule --add app=\"A\" manage=off"),
                                      autoPaddingOriginal: nil)
        XCTAssertEqual([v.settings.topPadding, v.settings.bottomPadding, v.settings.leftPadding,
                        v.settings.rightPadding, v.settings.gap], [0, 0, 0, 0, 0])
        XCTAssertEqual(v.settings.layout, .off)
        XCTAssertEqual(v.settings.rules, [WindowRule(app: "A", mode: .float)])
    }
    func testLiveFieldMissingFallsBackToFileThenBuiltInDefault() {
        let v = FaithfulYabai.compose(live: YabaiLiveState(layout: "bsp"),
                                      file: YabaiFileState.parse("yabai -m config window_gap 6"), autoPaddingOriginal: nil)
        XCTAssertEqual(v.settings.gap, 6)
        XCTAssertEqual(v.settings.topPadding, 0)
        XCTAssertEqual(v.settings.layout, .bsp)
    }

    /// I2: a layout the panel can't represent is surfaced, live first.
    func testUnrepresentableLayoutIsExposed() {
        XCTAssertEqual(YabaiFileState.parse("yabai -m config layout stack").unrepresentedLayout, "stack")
        XCTAssertNil(YabaiFileState.parse("yabai -m config layout stack\nyabai -m config layout bsp").unrepresentedLayout)
        let live = FaithfulYabai.compose(live: YabaiLiveState(layout: "stack"),
                                         file: YabaiFileState.parse("yabai -m config layout bsp"), autoPaddingOriginal: nil)
        XCTAssertEqual(live.unrepresentedLayout, "stack")
        XCTAssertNil(live.fieldDiffs[.layout])
        let file = FaithfulYabai.compose(live: nil, file: YabaiFileState.parse("yabai -m config layout stack"),
                                         autoPaddingOriginal: nil)
        XCTAssertEqual(file.unrepresentedLayout, "stack")
        let liveWins = FaithfulYabai.compose(live: YabaiLiveState(layout: "bsp"),
                                             file: YabaiFileState.parse("yabai -m config layout stack"), autoPaddingOriginal: nil)
        XCTAssertNil(liveWins.unrepresentedLayout)
        XCTAssertEqual(liveWins.settings.layout, .bsp)
    }

    /// I5: only a bare `app=".*" manage=off` (sub-layer allowed) is the Float catch-all,
    /// and it is hidden only while the layout is Float.
    func testFileCatchAllStrictAndHiddenOnlyForFloat() {
        let titled = "yabai -m rule --add app=\".*\" title=\"Preferences\" manage=off"
        let f1 = YabaiFileState.parse("yabai -m config layout float\n" + titled)
        XCTAssertEqual(f1.layout, .off)
        XCTAssertEqual(f1.otherRules, [titled])
        let bare = "yabai -m rule --add app=\".*\" manage=off sub-layer=normal"
        let f2 = YabaiFileState.parse("yabai -m config layout float\n" + bare)
        XCTAssertEqual(f2.layout, .float)
        XCTAssertEqual(f2.otherRules, [])
        let f3 = YabaiFileState.parse("yabai -m config layout bsp\n" + bare)
        XCTAssertEqual(f3.layout, .bsp)
        XCTAssertEqual(f3.otherRules, [bare])
        // No layout line: yabai's built-in float, which the catch-all makes Float.
        let f4 = YabaiFileState.parse(bare)
        XCTAssertEqual(f4.layout, .float)
        XCTAssertEqual(f4.otherRules, [])
    }
    func testLiveCatchAllStrictAndHiddenOnlyForFloat() {
        func rule(_ title: String) -> String {
            #"{"app":".*","title":"\#(title)","role":"","subrole":"","label":"","scratchpad":"","display":0,"space":0,"opacity":0.0,"manage":false,"sticky":null,"mouse_follows_focus":null,"sub-layer":"normal","native-fullscreen":null,"grid":"0:0:0:0:0:0","one-shot":false}"#
        }
        let titled = LiveRule.decodeList(Data("[\(rule("Preferences"))]".utf8))
        XCTAssertEqual(titled.first?.isCatchAll, false)
        let tv = FaithfulYabai.compose(live: YabaiLiveState(layout: "float", rules: titled), file: YabaiFileState(),
                                       autoPaddingOriginal: nil)
        XCTAssertEqual(tv.settings.layout, .off)
        XCTAssertEqual(tv.otherRules.count, 1)
        let bare = LiveRule.decodeList(Data("[\(rule(""))]".utf8))
        XCTAssertEqual(bare.first?.isCatchAll, true)
        let fv = FaithfulYabai.compose(live: YabaiLiveState(layout: "float", rules: bare), file: YabaiFileState(),
                                       autoPaddingOriginal: nil)
        XCTAssertEqual(fv.settings.layout, .float)
        XCTAssertEqual(fv.otherRules, [])
        let bv = FaithfulYabai.compose(live: YabaiLiveState(layout: "bsp", rules: bare), file: YabaiFileState(),
                                       autoPaddingOriginal: nil)
        XCTAssertEqual(bv.settings.layout, .bsp)
        XCTAssertEqual(bv.otherRules.count, 1)
    }
}
