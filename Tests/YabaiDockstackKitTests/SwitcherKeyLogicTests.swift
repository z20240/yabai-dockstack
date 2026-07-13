import XCTest
@testable import YabaiDockstackKit

final class SwitcherKeyLogicTests: XCTestCase {
    private let altTab = SwitcherTrigger(keycode: 0x30, mods: [.alt], scope: .allWindows)
    private let altBacktick = SwitcherTrigger(keycode: 0x32, mods: [.alt], scope: .currentApp)
    private var triggers: [SwitcherTrigger] { [altTab, altBacktick] }

    func testActivateOnTriggerPress() {
        var m = SwitcherKeyMachine()
        let out = m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: triggers)
        XCTAssertEqual(out, .activate(trigger: 0, backward: false))
        XCTAssertEqual(m.activeTrigger, 0)
    }

    func testShiftActivatesBackward() {
        var m = SwitcherKeyMachine()
        let out = m.handle(.keyDown(code: 0x30, mods: [.alt, .shift]), triggers: triggers)
        XCTAssertEqual(out, .activate(trigger: 0, backward: true))
    }

    func testExtraModifierDoesNotActivate() {
        var m = SwitcherKeyMachine()
        // cmd+alt+tab is a different shortcut — must pass through untouched.
        let out = m.handle(.keyDown(code: 0x30, mods: [.alt, .cmd]), triggers: triggers)
        XCTAssertEqual(out, .pass)
        XCTAssertNil(m.activeTrigger)
    }

    func testUnrelatedKeysPassWhenIdle() {
        var m = SwitcherKeyMachine()
        XCTAssertEqual(m.handle(.keyDown(code: 0x00, mods: []), triggers: triggers), .pass)
        XCTAssertEqual(m.handle(.flagsChanged(mods: [.alt]), triggers: triggers), .pass)
    }

    func testRepeatPressCyclesForwardAndBackward() {
        var m = SwitcherKeyMachine()
        _ = m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: triggers)
        XCTAssertEqual(m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: triggers),
                       .cycle(forward: true))
        XCTAssertEqual(m.handle(.keyDown(code: 0x30, mods: [.alt, .shift]), triggers: triggers),
                       .cycle(forward: false))
    }

    func testReleaseModifierCommits() {
        var m = SwitcherKeyMachine()
        _ = m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: triggers)
        // Adding a modifier (shift for backward) must NOT commit.
        XCTAssertEqual(m.handle(.flagsChanged(mods: [.alt, .shift]), triggers: triggers), .pass)
        XCTAssertEqual(m.handle(.flagsChanged(mods: []), triggers: triggers),
                       .commit(consume: false))
        XCTAssertNil(m.activeTrigger)
    }

    func testEnterCommitsAndEscapeCancels() {
        var m = SwitcherKeyMachine()
        _ = m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: triggers)
        XCTAssertEqual(m.handle(.keyDown(code: 0x24, mods: [.alt]), triggers: triggers),
                       .commit(consume: true))
        XCTAssertNil(m.activeTrigger)

        _ = m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: triggers)
        XCTAssertEqual(m.handle(.keyDown(code: 0x35, mods: [.alt]), triggers: triggers), .cancel)
        XCTAssertNil(m.activeTrigger)
    }

    func testArrowsMoveAndWCloses() {
        var m = SwitcherKeyMachine()
        _ = m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: triggers)
        XCTAssertEqual(m.handle(.keyDown(code: 0x7B, mods: [.alt]), triggers: triggers),
                       .move(dx: -1, dy: 0))
        XCTAssertEqual(m.handle(.keyDown(code: 0x7C, mods: [.alt]), triggers: triggers),
                       .move(dx: 1, dy: 0))
        XCTAssertEqual(m.handle(.keyDown(code: 0x7E, mods: [.alt]), triggers: triggers),
                       .move(dx: 0, dy: -1))
        XCTAssertEqual(m.handle(.keyDown(code: 0x7D, mods: [.alt]), triggers: triggers),
                       .move(dx: 0, dy: 1))
        XCTAssertEqual(m.handle(.keyDown(code: 0x0D, mods: [.alt]), triggers: triggers),
                       .closeSelected)
    }

    func testOtherKeysSwallowedWhileActive() {
        var m = SwitcherKeyMachine()
        _ = m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: triggers)
        XCTAssertEqual(m.handle(.keyDown(code: 0x00, mods: [.alt]), triggers: triggers), .swallow)
    }

    func testOtherTriggerKeySwitchesScope() {
        var m = SwitcherKeyMachine()
        _ = m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: triggers)
        let out = m.handle(.keyDown(code: 0x32, mods: [.alt]), triggers: triggers)
        XCTAssertEqual(out, .activate(trigger: 1, backward: false))
        XCTAssertEqual(m.activeTrigger, 1)
    }

    func testDeactivateStopsSwallowing() {
        var m = SwitcherKeyMachine()
        _ = m.handle(.keyDown(code: 0x30, mods: [.alt]), triggers: triggers)
        m.deactivate()
        XCTAssertEqual(m.handle(.keyDown(code: 0x00, mods: [.alt]), triggers: triggers), .pass)
    }

    func testTriggersBuildFromConfig() {
        var c = AppConfig.defaults
        c.switcherHotkeyAll = "alt - tab"
        c.switcherHotkeyApp = "alt - 0x32"
        c.switcherHotkeySpace = ""
        let t = SwitcherTriggers.build(from: c)
        XCTAssertEqual(t, [SwitcherTrigger(keycode: 0x30, mods: [.alt], scope: .allWindows),
                           SwitcherTrigger(keycode: 0x32, mods: [.alt], scope: .currentApp)])
    }

    func testTriggersSkipModifierlessAndUnparseable() {
        var c = AppConfig.defaults
        c.switcherHotkeyAll = "tab"        // no modifier → cannot hold-to-cycle
        c.switcherHotkeyApp = "garbage"
        c.switcherHotkeySpace = "ctrl - space"
        let t = SwitcherTriggers.build(from: c)
        XCTAssertEqual(t, [SwitcherTrigger(keycode: 0x31, mods: [.ctrl], scope: .currentSpace)])
    }

    func testExactModifierMatchBeatsShiftTolerantOrdering() {
        // A shift-variant trigger on the same keycode must stay reachable even
        // though it sits after the shift-tolerant all-windows trigger.
        let shifted = SwitcherTrigger(keycode: 0x30, mods: [.alt, .shift], scope: .currentSpace)
        var m = SwitcherKeyMachine()
        let out = m.handle(.keyDown(code: 0x30, mods: [.alt, .shift]),
                           triggers: [altTab, shifted])
        XCTAssertEqual(out, .activate(trigger: 1, backward: false))
    }

    func testCaptureCmdTabOverridesAllScope() {
        var c = AppConfig.defaults
        c.switcherCaptureCmdTab = true
        c.switcherHotkeyAll = "alt - tab"
        let t = SwitcherTriggers.build(from: c)
        XCTAssertEqual(t.first, SwitcherTrigger(keycode: 0x30, mods: [.cmd], scope: .allWindows))
        XCTAssertFalse(t.contains(SwitcherTrigger(keycode: 0x30, mods: [.alt], scope: .allWindows)))
    }
}
