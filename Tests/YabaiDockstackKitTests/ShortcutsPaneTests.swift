import AppKit
import XCTest
@testable import YabaiDockstackKit

final class ShortcutsPaneTests: XCTestCase {
    @MainActor
    func testManagementToggleEnablesControlsAndReportsPreferenceChanges() throws {
        _ = NSApplication.shared
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("skhdrc").path
        let engine = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                                  yabaiConfigPath: path, skhdConfigPath: path + ".s", scriptsDir: "/S")
        var changes: [Bool] = []
        let pane = ShortcutsPaneView(engine: engine, rawFilePath: path) { changes.append($0) }
        func descendants(_ view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + descendants($0) }
        }
        let views = descendants(pane)
        let toggle = try XCTUnwrap(views.compactMap { $0 as? NSButton }.first {
            $0.title == L10n.t("ui.keyboard.manageConfig")
        })
        let editors = views.compactMap { $0 as? NSControl }.filter {
            $0 !== toggle && ($0 is NSButton || $0 is NSSegmentedControl
                             || ($0 as? NSTextField)?.isEditable == true)
        }
        XCTAssertGreaterThan(editors.count, 10)
        XCTAssertTrue(toggle.isEnabled)
        XCTAssertEqual(toggle.state, .off)
        XCTAssertTrue(editors.allSatisfy { !$0.isEnabled })

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
}
