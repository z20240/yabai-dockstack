import AppKit
import XCTest
@testable import YabaiDockstackKit

final class SkhdSettingsTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }

    @MainActor
    func testSearchShortcutRequiresSkhdOptInWhileHoldShortcutsRemainEditable() throws {
        _ = NSApplication.shared
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = SettingsWindowController(config: .defaults, onChange: { _ in },
                                                  onLoginToggle: { _ in }, loginIsEnabled: { false })
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        controller.configEngine = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                                                yabaiConfigPath: path, skhdConfigPath: path + ".s",
                                                scriptsDir: "/S")
        controller.selectTab(at: 3)
        let window = try XCTUnwrap(NSApp.windows.first {
            !existingWindows.contains(ObjectIdentifier($0)) && $0.contentView is NSTabView
        })
        defer { window.close() }
        let root = try XCTUnwrap(window.contentView)
        let tabs = try XCTUnwrap(root as? NSTabView)
        let switcher = try XCTUnwrap(tabs.selectedTabViewItem?.view)
        let recorders = descendants(switcher).compactMap { $0 as? RecordHotkeyControl }
        XCTAssertEqual(recorders.count, 4)
        XCTAssertEqual(recorders.filter(\.isEnabled).count, 3)
        let searchRecorder = try XCTUnwrap(recorders.first { !$0.isEnabled })
        var config = AppConfig.defaults
        config.manageSkhdConfig = true
        controller.updateConfig(config)
        XCTAssertTrue(searchRecorder.isEnabled)
        XCTAssertTrue(recorders.allSatisfy(\.isEnabled))
        controller.updateConfig(.defaults)
        XCTAssertFalse(searchRecorder.isEnabled)
        XCTAssertEqual(recorders.filter(\.isEnabled).count, 3)
    }

    @MainActor
    func testDisablingRecorderStopsRecordingAndDisablesButtons() throws {
        _ = NSApplication.shared
        let recorder = RecordHotkeyControl(frame: .zero)
        let buttons = descendants(recorder).compactMap { $0 as? NSButton }
        let record = try XCTUnwrap(buttons.first { $0.title == L10n.t("ui.record.prompt") })
        record.performClick(nil)
        XCTAssertEqual(record.title, L10n.t("ui.record.recording"))
        recorder.isEnabled = false
        XCTAssertEqual(record.title, L10n.t("ui.record.prompt"))
        XCTAssertTrue(buttons.allSatisfy { !$0.isEnabled })
    }
}
