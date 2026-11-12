import AppKit
import XCTest
@testable import YabaiDockstackKit

final class ShortcutsPaneTests: XCTestCase {

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

    private static let handWritten =
        "cmd - f3: sh ~/.config/yabai/scripts/taggleShowHideDesktop.sh\nalt - x : open -a Terminal\n"

    private func makeEngine(fileText: String?, allow: Bool = false) throws -> (ConfigEngine, String) {
        let path = dir.appendingPathComponent("skhdrc").path
        if let fileText {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try fileText.write(toFile: path, atomically: true, encoding: .utf8)
        }
        let engine = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                                  yabaiConfigPath: path + ".y", skhdConfigPath: path,
                                  scriptsDir: "/Users/me/.config/yabai-dockstack/scripts",
                                  manageSkhdConfig: allow)
        return (engine, path)
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
            $0.title == L10n.t("ui.keyboard.manageConfig")
        })
    }

    private func button(_ pane: NSView, _ key: String) throws -> NSButton {
        try XCTUnwrap(descendants(pane).compactMap { $0 as? NSButton }.first { $0.title == L10n.t(key) },
                      "no button \(key)")
    }

    private func recorder(_ pane: NSView, _ actionID: String) throws -> RecordHotkeyControl {
        try XCTUnwrap(descendants(pane).compactMap { $0 as? RecordHotkeyControl }.first {
            $0.identifier?.rawValue == actionID
        }, "no recorder \(actionID)")
    }

    private func otherList(_ pane: NSView) throws -> CollapsibleListView {
        try XCTUnwrap(descendants(pane).compactMap { $0 as? CollapsibleListView }.first)
    }

    /// rc-backed editors: everything editable except the allow toggle, the rc row,
    /// the read-only "Other shortcuts" list and the Reload button.
    private func editors(_ pane: NSView) throws -> [NSControl] {
        let t = try toggle(pane)
        let reloadTitle = L10n.t("ui.rc.reload")
        return descendants(pane).compactMap { $0 as? NSControl }.filter {
            $0 !== t && !isInside($0, RcFileRowView.self) && !isInside($0, CollapsibleListView.self)
                && ($0 as? NSButton)?.title != reloadTitle
                && ($0 is NSButton || $0 is NSSegmentedControl || ($0 as? NSTextField)?.isEditable == true)
        }
    }

    private func statusShows(_ pane: NSView, containing s: String) -> Bool {
        descendants(pane).contains { ($0 as? NSTextField)?.stringValue.contains(s) == true }
    }

    private let cmdF3 = Hotkey(mods: [.cmd], key: "f3")

    // MARK: - Tests

    @MainActor
    func testManagementToggleEnablesControlsAndReportsPreferenceChanges() throws {
        _ = NSApplication.shared
        let (engine, _) = try makeEngine(fileText: nil)
        var changes: [Bool] = []
        let pane = ShortcutsPaneView(engine: engine) { changes.append($0) }
        let toggle = try toggle(pane)
        let editors = try editors(pane)
        XCTAssertGreaterThan(editors.count, 10)
        XCTAssertTrue(toggle.isEnabled)
        XCTAssertEqual(toggle.state, .off)
        XCTAssertTrue(editors.allSatisfy { !$0.isEnabled })
        XCTAssertTrue(try button(pane, "ui.rc.open").isEnabled)
        XCTAssertTrue(try button(pane, "ui.rc.reload").isEnabled)

        toggle.performClick(nil)
        XCTAssertTrue(engine.manageSkhdConfig)
        XCTAssertTrue(editors.allSatisfy(\.isEnabled))
        toggle.performClick(nil)
        XCTAssertFalse(engine.manageSkhdConfig)
        XCTAssertTrue(editors.allSatisfy { !$0.isEnabled })
        XCTAssertEqual(changes, [true, false])
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path),
                       "Toggling management must not itself create or import skhdrc")
    }

    @MainActor
    func testNotAllowShowsFileBindingNotDefaults() throws {
        _ = NSApplication.shared
        let (engine, _) = try makeEngine(fileText: Self.handWritten)
        let pane = ShortcutsPaneView(engine: engine)
        XCTAssertEqual(try recorder(pane, "toggle-show-desktop").hotkey, cmdF3)
        // A catalog action the file doesn't bind is unbound, not the default template's key.
        XCTAssertNotNil(DefaultTemplate.defaultBindings().first { $0.actionID == "close-window" }?.hotkey)
        XCTAssertNil(try recorder(pane, "close-window").hotkey)
        let list = try otherList(pane)
        XCTAssertFalse(list.isHidden)
        XCTAssertTrue(list.title.contains("(1)"), list.title)
        XCTAssertEqual(list.title, String(format: L10n.t("ui.keyboard.otherShortcuts"), 1))
        XCTAssertFalse(list.isExpanded)
        XCTAssertEqual(list.items, ["alt - x : open -a Terminal"])
        XCTAssertTrue(try editors(pane).allSatisfy { !$0.isEnabled })
    }

    @MainActor
    func testOtherShortcutsHiddenInAllowMode() throws {
        _ = NSApplication.shared
        let (engine, _) = try makeEngine(fileText: Self.handWritten)
        let pane = ShortcutsPaneView(engine: engine)
        let list = try otherList(pane)
        XCTAssertFalse(list.isHidden)
        try toggle(pane).performClick(nil)   // not allow → allow
        XCTAssertTrue(list.isHidden)
        XCTAssertEqual(try recorder(pane, "toggle-show-desktop").hotkey, cmdF3, "allow keeps faithful values")
        try toggle(pane).performClick(nil)   // allow → not allow
        XCTAssertFalse(list.isHidden)
    }

    @MainActor
    func testDisallowDiscardsUnsavedBindingEdits() throws {
        _ = NSApplication.shared
        let (engine, _) = try makeEngine(fileText: Self.handWritten, allow: true)
        let pane = ShortcutsPaneView(engine: engine)
        let rec = try recorder(pane, "toggle-show-desktop")
        XCTAssertEqual(rec.hotkey, cmdF3)
        XCTAssertFalse(pane.hasUnsavedEdits)
        let edited = Hotkey(mods: [.alt], key: "f9")
        rec.hotkey = edited
        rec.onChange?(edited)                 // what a recording does
        XCTAssertTrue(pane.hasUnsavedEdits)
        pane.reload(force: false)
        XCTAssertEqual(try recorder(pane, "toggle-show-desktop").hotkey, edited,
                       "non-forced reload keeps unsaved edits")

        try toggle(pane).performClick(nil)   // allow → not allow
        XCTAssertEqual(try recorder(pane, "toggle-show-desktop").hotkey, cmdF3)
        XCTAssertFalse(pane.hasUnsavedEdits)
        try toggle(pane).performClick(nil)   // not allow → allow
        XCTAssertEqual(try recorder(pane, "toggle-show-desktop").hotkey, cmdF3)
    }

    @MainActor
    func testSetBindingKeepsOtherUnsavedEdits() throws {
        _ = NSApplication.shared
        let (engine, _) = try makeEngine(fileText: Self.handWritten, allow: true)
        let pane = ShortcutsPaneView(engine: engine)
        let edited = Hotkey(mods: [.alt], key: "f9")
        let rowA = try recorder(pane, "toggle-show-desktop")
        rowA.hotkey = edited
        rowA.onChange?(edited)
        XCTAssertTrue(pane.hasUnsavedEdits)

        let x = Hotkey(mods: [.cmd, .shift], key: "space")
        pane.setBinding(actionID: "open-window-switcher", hotkey: x)
        XCTAssertEqual(try recorder(pane, "open-window-switcher").hotkey, x)
        XCTAssertEqual(try recorder(pane, "toggle-show-desktop").hotkey, edited, "row A edit still present")
        XCTAssertTrue(pane.hasUnsavedEdits, "row A is still unsaved")

        pane.setBinding(actionID: "open-window-switcher", hotkey: nil)
        XCTAssertNil(try recorder(pane, "open-window-switcher").hotkey)
        XCTAssertEqual(try recorder(pane, "toggle-show-desktop").hotkey, edited)
    }

    @MainActor
    func testApplyCancelledWritesNothing() throws {
        _ = NSApplication.shared
        let (engine, path) = try makeEngine(fileText: Self.handWritten, allow: true)
        let pane = ShortcutsPaneView(engine: engine)
        var asked: ApplyPlan?
        pane.confirm = { plan, _ in asked = plan; return false }
        try button(pane, "ui.apply").performClick(nil)
        XCTAssertEqual(asked?.regionExists, false)
        XCTAssertEqual(asked?.linesToComment, 1)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), Self.handWritten)
    }

    @MainActor
    func testApplyConfirmedWritesRegion() throws {
        _ = NSApplication.shared
        let (engine, path) = try makeEngine(fileText: Self.handWritten, allow: true)
        let pane = ShortcutsPaneView(engine: engine)
        var askedPath: String?
        pane.confirm = { _, p in askedPath = p; return true }
        try button(pane, "ui.apply").performClick(nil)
        XCTAssertEqual(askedPath, path)
        let out = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(out.contains("# [yabai-dockstack imported] cmd - f3"), out)
        XCTAssertTrue(out.contains("alt - x : open -a Terminal"), out)
        XCTAssertTrue(out.contains(ManagedRegion.beginLine), out)
        XCTAssertFalse(pane.hasUnsavedEdits)
        // The re-parsed file still binds the action to cmd - f3 (now from the region).
        XCTAssertEqual(engine.faithfulSkhd().bindings.first { $0.actionID == "toggle-show-desktop" }?.hotkey, cmdF3)
    }

    @MainActor
    func testApplyWithRegionAndNothingToCommentDoesNotAsk() throws {
        _ = NSApplication.shared
        let region = ManagedRegion.replace(in: "", with: SkhdManagedConfig.generate(
            [ShortcutBinding(actionID: "toggle-show-desktop", enabled: true, hotkey: cmdF3)],
            catalog: ShortcutCatalog.all, scriptsDir: "/Users/me/.config/yabai-dockstack/scripts"))
        let (engine, _) = try makeEngine(fileText: region, allow: true)
        let pane = ShortcutsPaneView(engine: engine)
        XCTAssertEqual(try recorder(pane, "toggle-show-desktop").hotkey, cmdF3)
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
        let pane = ShortcutsPaneView(engine: engine)
        pane.confirm = { _, _ in true }
        try button(pane, "ui.apply").performClick(nil)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), text)
        XCTAssertTrue(statusShows(pane, containing: "malformed"))
    }

    @MainActor
    func testImportStartsFromFaithfulBindings() throws {
        _ = NSApplication.shared
        let (engine, path) = try makeEngine(fileText: Self.handWritten, allow: true)
        let pane = ShortcutsPaneView(engine: engine)
        try button(pane, "ui.importExisting").performClick(nil)
        let out = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(out.contains("# [yabai-dockstack imported] cmd - f3"), out)
        let fileBindings = engine.faithfulSkhd().bindings
        XCTAssertEqual(fileBindings.first { $0.actionID == "toggle-show-desktop" }?.hotkey, cmdF3)
        XCTAssertNil(fileBindings.first { $0.actionID == "close-window" }?.hotkey,
                     "import must not write the default template's bindings")
        XCTAssertEqual(try recorder(pane, "toggle-show-desktop").hotkey, cmdF3)
    }

    @MainActor
    func testOpenInEditorDoesNotCreateFileWhenNotAllowed() throws {
        _ = NSApplication.shared
        let (engine, path) = try makeEngine(fileText: nil)
        let pane = ShortcutsPaneView(engine: engine)
        try button(pane, "ui.rc.open").performClick(nil)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
        XCTAssertTrue(statusShows(pane, containing: "doesn't exist"))
    }

    // MARK: - Shared rc UI copy (R8)

    func testApplyConfirmBodyChosenByCount() {
        let path = "/tmp/rc/skhdrc"
        let newRegion = ApplyConfirmAlert.informativeText(
            plan: ApplyPlan(regionExists: false, linesToComment: 0), path: path)
        XCTAssertEqual(newRegion, String(format: L10n.t("ui.apply.confirmBodyNewRegion"), path))
        XCTAssertFalse(newRegion.contains("comment out"), newRegion)
        let commenting = ApplyConfirmAlert.informativeText(
            plan: ApplyPlan(regionExists: false, linesToComment: 2), path: path)
        XCTAssertEqual(commenting, String(format: L10n.t("ui.apply.confirmBody"), 2, path))
        L10n.current = .zhHant
        XCTAssertTrue(ApplyConfirmAlert.informativeText(
            plan: ApplyPlan(regionExists: true, linesToComment: 3), path: path).contains("3"))
        L10n.current = .en
    }

    @MainActor
    func testRcRowShowsCreateFailedWhenCreationFails() {
        _ = NSApplication.shared
        var status: (Bool, String)?
        let row = RcFileRowView(tool: .skhd, sources: .none, canCreateFile: { true },
                                onStatus: { status = ($0, $1) })
        var opened: String?
        row.openFile = { opened = $0 }
        // /System is read-only: the parent exists but the file can't be created.
        let path = "/System/dockstack-test-\(UUID().uuidString)"
        row.update(effectivePath: path)
        row.subviews.flatMap { $0.subviews }.compactMap { $0 as? NSButton }
            .first { $0.title == L10n.t("ui.rc.open") }?.performClick(nil)
        XCTAssertNil(opened)
        XCTAssertEqual(status?.0, false)
        XCTAssertEqual(status?.1, String(format: L10n.t("ui.rc.createFailed"), path))
    }
}
