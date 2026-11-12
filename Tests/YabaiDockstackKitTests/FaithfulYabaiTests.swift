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
        XCTAssertEqual(v.settings.topPadding, YabaiSettings.defaults.topPadding)
    }
}
