import XCTest
@testable import YabaiDockstackKit

final class FaithfulSkhdTests: XCTestCase {
    func testParseMatchesCatalogAndCollectsOthers() {
        let text = "cmd - f3: sh ~/.config/yabai/scripts/taggleShowHideDesktop.sh\ncmd - f4: sh ~/.config/yabai/scripts/taggleShowHideDesktop.sh\nalt - x : open -a Terminal\n# comment\n:: resize\nalt - r : \\\n  yabai -m window --resize left:-20:0"
        let v = FaithfulSkhd.parse(text, catalog: ShortcutCatalog.all, scriptsDir: "/Users/me/.config/yabai-dockstack/scripts")
        XCTAssertEqual(v.bindings.count, ShortcutCatalog.all.count)
        XCTAssertEqual(v.bindings.first { $0.actionID == "toggle-show-desktop" }?.hotkey, Hotkey(mods: [.cmd], key: "f3"))
        XCTAssertEqual(v.others, ["cmd - f4: sh ~/.config/yabai/scripts/taggleShowHideDesktop.sh", "alt - x : open -a Terminal",
                                  ":: resize", "alt - r : \\", "yabai -m window --resize left:-20:0"])
    }
    func testUnmatchedCatalogActionsAreUnboundNotDefaults() {
        let v = FaithfulSkhd.parse("", catalog: ShortcutCatalog.all, scriptsDir: "/S")
        XCTAssertTrue(v.bindings.allSatisfy { !$0.enabled && $0.hotkey == nil })
        XCTAssertTrue(v.others.isEmpty)
    }
}
