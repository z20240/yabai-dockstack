import XCTest
@testable import YabaiDockstackKit

final class SkhdManagedConfigTests: XCTestCase {
    func testGenerateSkipsDisabledAndUnbound() {
        let bindings = [
            ShortcutBinding(actionID: "balance", enabled: true, hotkey: Hotkey(mods: [.alt, .cmd], key: "0x2A")),
            ShortcutBinding(actionID: "toggle-fullscreen", enabled: false, hotkey: Hotkey(mods: [.alt, .cmd], key: "space")),
            ShortcutBinding(actionID: "rotate-cw", enabled: true, hotkey: nil),
        ]
        let text = SkhdManagedConfig.generate(bindings, catalog: ShortcutCatalog.all, scriptsDir: "/S")
        XCTAssertTrue(text.contains("alt + cmd - 0x2A : yabai -m space --balance"))
        XCTAssertFalse(text.contains("zoom-fullscreen"))  // disabled
        XCTAssertFalse(text.contains("rotate"))           // unbound
    }

    func testScriptTokenSubstituted() {
        let b = [ShortcutBinding(actionID: "toggle-show-desktop", enabled: true, hotkey: Hotkey(mods: [.cmd], key: "f3"))]
        let text = SkhdManagedConfig.generate(b, catalog: ShortcutCatalog.all, scriptsDir: "/opt/s")
        XCTAssertTrue(text.contains("cmd - f3 : sh /opt/s/taggleShowHideDesktop.sh"))
        XCTAssertFalse(text.contains("${SCRIPTS}"))
    }

    func testRoundTrip() {
        // Bindings must be in catalog order because generate() emits in catalog order;
        // parse() returns lines in the same order they appear in the generated text.
        let bindings = [
            ShortcutBinding(actionID: "focus-left", enabled: true, hotkey: Hotkey(mods: [.alt, .cmd], key: "left")),
            ShortcutBinding(actionID: "balance", enabled: true, hotkey: Hotkey(mods: [.alt, .cmd], key: "0x2A")),
        ]
        let text = SkhdManagedConfig.generate(bindings, catalog: ShortcutCatalog.all, scriptsDir: "/S")
        let parsed = SkhdManagedConfig.parse(text, catalog: ShortcutCatalog.all, scriptsDir: "/S")
        XCTAssertEqual(parsed, bindings)
    }
}
