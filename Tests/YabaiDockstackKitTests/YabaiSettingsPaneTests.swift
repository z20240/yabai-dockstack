import AppKit
import XCTest
@testable import YabaiDockstackKit

final class YabaiSettingsPaneTests: XCTestCase {

    // MARK: - Helpers

    private var dir: URL!

    override func setUp() {
        super.setUp()
        L10n.current = .en
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func makeEngine(fileText: String?, allow: Bool = false) throws -> (ConfigEngine, String) {
        let path = dir.appendingPathComponent("yabairc").path
        if let fileText {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try fileText.write(toFile: path, atomically: true, encoding: .utf8)
        }
        let engine = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                                  yabaiConfigPath: path, skhdConfigPath: path + ".s", scriptsDir: "/S",
                                  manageYabaiConfig: allow)
        return (engine, path)
    }

    private func sources(live: YabaiLiveState?) -> RcSources {
        var s = RcSources.none
        s.liveYabai = { live }
        return s
    }

    private func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }

    private func isInside<T: NSView>(_ view: NSView, _ type: T.Type) -> Bool {
        var v = view.superview
        while let cur = v { if cur is T { return true }; v = cur.superview }
        return false
    }

    private func toggle(_ pane: NSView) throws -> NSButton {
        try XCTUnwrap(descendants(pane).compactMap { $0 as? NSButton }.first {
            $0.title == L10n.t("ui.yabai.manageConfig")
        })
    }

    private func button(_ pane: NSView, _ key: String) throws -> NSButton {
        try XCTUnwrap(descendants(pane).compactMap { $0 as? NSButton }.first { $0.title == L10n.t(key) },
                      "no button \(key)")
    }

    /// rc-backed editors: everything editable except the allow toggle, the rc row,
    /// the read-only "Other rules" list and the Reload button.
    private func editors(_ pane: NSView) throws -> [NSControl] {
        let t = try toggle(pane)
        let reloadTitle = L10n.t("ui.rc.reload")
        return descendants(pane).compactMap { $0 as? NSControl }.filter {
            $0 !== t && !isInside($0, RcFileRowView.self) && !isInside($0, CollapsibleListView.self)
                && ($0 as? NSButton)?.title != reloadTitle
                && ($0 is NSButton || $0 is NSSegmentedControl || ($0 as? NSTextField)?.isEditable == true)
        }
    }

    private func gapField(_ pane: NSView) throws -> NSTextField {
        // The gap field is the editable text field in the form row labelled "Gap:".
        let row = try XCTUnwrap(descendants(pane).compactMap { $0 as? NSStackView }.first { s in
            s.views.contains { ($0 as? NSTextField)?.stringValue == L10n.t("ui.yabai.gap") }
        })
        return try XCTUnwrap(row.views.compactMap { $0 as? NSTextField }.first { $0.isEditable })
    }

    private func badges(_ pane: NSView) -> [NSTextField] {
        descendants(pane).compactMap { $0 as? NSTextField }.filter { $0.stringValue == "!" && !$0.isHidden }
    }

    // MARK: - Tests

    @MainActor
    func testManagementToggleEnablesControlsAndReportsPreferenceChanges() throws {
        _ = NSApplication.shared
        let (engine, _) = try makeEngine(fileText: nil)
        var changes: [Bool] = []
        let pane = YabaiSettingsPaneView(engine: engine) { changes.append($0) }
        let toggle = try toggle(pane)
        let editors = try editors(pane)
        XCTAssertGreaterThan(editors.count, 8)
        XCTAssertTrue(toggle.isEnabled)
        XCTAssertEqual(toggle.state, .off)
        XCTAssertTrue(editors.allSatisfy { !$0.isEnabled })

        toggle.performClick(nil)
        XCTAssertTrue(engine.manageYabaiConfig)
        XCTAssertTrue(editors.allSatisfy(\.isEnabled))
        toggle.performClick(nil)
        XCTAssertFalse(engine.manageYabaiConfig)
        XCTAssertTrue(editors.allSatisfy { !$0.isEnabled })
        XCTAssertEqual(changes, [true, false])
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path),
                       "Toggling management must not itself create or import yabairc")
    }

    @MainActor
    func testNotAllowShowsLiveValuesWithTooltipBadge() throws {
        _ = NSApplication.shared
        let (engine, _) = try makeEngine(fileText: "yabai -m config window_gap 6\n")
        let pane = YabaiSettingsPaneView(engine: engine,
                                         sources: sources(live: YabaiLiveState(layout: "bsp", gap: 10)))
        XCTAssertEqual(try gapField(pane).stringValue, "10")
        let bang = try XCTUnwrap(badges(pane).first)
        let tip = try XCTUnwrap(bang.toolTip)
        XCTAssertTrue(tip.contains("6") && tip.contains("10"), tip)
        XCTAssertTrue(try editors(pane).allSatisfy { !$0.isEnabled })
        XCTAssertTrue(try button(pane, "ui.rc.open").isEnabled)
        XCTAssertTrue(try button(pane, "ui.rc.reload").isEnabled)
    }

    @MainActor
    func testYabaiNotRunningShowsFileValues() throws {
        _ = NSApplication.shared
        let (engine, _) = try makeEngine(fileText: "yabai -m config window_gap 6\n")
        let pane = YabaiSettingsPaneView(engine: engine, sources: sources(live: nil))
        XCTAssertEqual(try gapField(pane).stringValue, "6")
        XCTAssertTrue(badges(pane).isEmpty)
        XCTAssertTrue(descendants(pane).contains {
            ($0 as? NSTextField)?.stringValue == L10n.t("ui.yabai.notRunning")
        })
    }

    @MainActor
    func testOpenInEditorDoesNotCreateFileWhenNotAllowed() throws {
        _ = NSApplication.shared
        let (engine, path) = try makeEngine(fileText: nil)
        let pane = YabaiSettingsPaneView(engine: engine)
        try button(pane, "ui.rc.open").performClick(nil)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    @MainActor
    func testDisallowDiscardsUnsavedEdits() throws {
        _ = NSApplication.shared
        let (engine, _) = try makeEngine(fileText: "yabai -m config window_gap 6\n", allow: true)
        let pane = YabaiSettingsPaneView(engine: engine)
        let gap = try gapField(pane)
        XCTAssertEqual(gap.stringValue, "6")
        gap.stringValue = "33"
        XCTAssertTrue(pane.hasUnsavedEdits)
        pane.reload(force: false)
        XCTAssertEqual(gap.stringValue, "33", "non-forced reload keeps unsaved edits")

        try toggle(pane).performClick(nil)   // allow → not allow
        XCTAssertEqual(gap.stringValue, "6")
        XCTAssertFalse(pane.hasUnsavedEdits)
        try toggle(pane).performClick(nil)   // not allow → allow
        XCTAssertEqual(gap.stringValue, "6")
    }

    @MainActor
    func testApplyCancelledWritesNothing() throws {
        _ = NSApplication.shared
        let text = "yabai -m config window_gap 6\n"
        let (engine, path) = try makeEngine(fileText: text, allow: true)
        let pane = YabaiSettingsPaneView(engine: engine)
        var asked: ApplyPlan?
        pane.confirm = { plan, _ in asked = plan; return false }
        try button(pane, "ui.apply").performClick(nil)
        XCTAssertEqual(asked?.regionExists, false)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), text)
    }

    @MainActor
    func testApplyConfirmedWritesRegion() throws {
        _ = NSApplication.shared
        let (engine, path) = try makeEngine(fileText: "yabai -m config window_gap 6\n", allow: true)
        let pane = YabaiSettingsPaneView(engine: engine)
        pane.confirm = { _, _ in true }
        try button(pane, "ui.apply").performClick(nil)
        let out = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(out.contains("# [yabai-dockstack imported] yabai -m config window_gap 6"), out)
        XCTAssertTrue(out.contains("window_gap 6"), out)
        XCTAssertFalse(pane.hasUnsavedEdits)
    }

    @MainActor
    func testApplyWithRegionAndNothingToCommentDoesNotAsk() throws {
        _ = NSApplication.shared
        let text = ManagedRegion.replace(in: "", with: YabaiManagedConfig.generate(YabaiSettings.defaults))
        let (engine, _) = try makeEngine(fileText: text, allow: true)
        let pane = YabaiSettingsPaneView(engine: engine)
        var asked = false
        pane.confirm = { _, _ in asked = true; return false }
        try button(pane, "ui.apply").performClick(nil)
        XCTAssertFalse(asked)
    }

    @MainActor
    func testApplySaveErrorShowsStatusAndKeepsFile() throws {
        _ = NSApplication.shared
        let text = ManagedRegion.beginLine + "\n" + ManagedRegion.beginLine + "\n"   // malformed
        let (engine, path) = try makeEngine(fileText: text, allow: true)
        let pane = YabaiSettingsPaneView(engine: engine)
        pane.confirm = { _, _ in true }
        try button(pane, "ui.apply").performClick(nil)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), text)
        XCTAssertTrue(descendants(pane).contains {
            ($0 as? NSTextField)?.stringValue.contains("malformed") == true
        })
    }

    @MainActor
    func testOtherRulesCollapsedByDefault() throws {
        _ = NSApplication.shared
        let (engine, _) = try makeEngine(fileText: "")
        let live = YabaiLiveState(layout: "bsp", rules: [
            LiveRule(windowRule: nil, summary: "app=\"Finder\" title=\"Copy\" manage=off", isCatchAll: false),
            LiveRule(windowRule: WindowRule(app: "Calculator", mode: .float), summary: "", isCatchAll: false),
        ])
        let pane = YabaiSettingsPaneView(engine: engine, sources: sources(live: live))
        let list = try XCTUnwrap(descendants(pane).compactMap { $0 as? CollapsibleListView }.first)
        XCTAssertFalse(list.isHidden)
        XCTAssertFalse(list.isExpanded)
        XCTAssertTrue(list.title.contains("(1)"), list.title)
        list.toggle()
        XCTAssertTrue(list.isExpanded)

        try toggle(pane).performClick(nil)   // allow mode hides "Other rules"
        XCTAssertTrue(list.isHidden)
    }

    @MainActor
    func testCollapsibleListHiddenWhenEmpty() {
        _ = NSApplication.shared
        let list = CollapsibleListView(titleKey: "ui.yabai.otherRules")
        list.setItems([])
        XCTAssertTrue(list.isHidden)
        list.setItems(["a", "b"])
        XCTAssertFalse(list.isHidden)
        XCTAssertFalse(list.isExpanded)
        XCTAssertEqual(list.title, String(format: L10n.t("ui.yabai.otherRules"), 2))
    }

    @MainActor
    func testRcRowWarnsOnlyWhenDetectedDiffers() {
        _ = NSApplication.shared
        var s = RcSources.none
        var detected = ""
        var override = ""
        s.detectedPath = { _ in detected }
        s.pathOverride = { _ in override }
        let row = RcFileRowView(tool: .yabai, sources: s, canCreateFile: { false }, onStatus: { _, _ in })
        row.update(effectivePath: "/tmp/a/yabairc")
        XCTAssertFalse(row.showsMismatchWarning, "no warning when detection is empty (R5)")
        XCTAssertFalse(row.showsResetToAuto)
        detected = "/tmp/b/yabairc"
        override = "/tmp/a/yabairc"
        row.update(effectivePath: "/tmp/a/yabairc")
        XCTAssertTrue(row.showsMismatchWarning)
        XCTAssertTrue(row.showsResetToAuto)
        detected = "/tmp/a/yabairc"
        row.update(effectivePath: "/tmp/a/yabairc")
        XCTAssertFalse(row.showsMismatchWarning)
    }
}
