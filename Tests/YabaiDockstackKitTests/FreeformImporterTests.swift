import XCTest
@testable import YabaiDockstackKit

final class FreeformImporterTests: XCTestCase {
    func testNormalizeCollapsesScriptDirs() {
        let a = FreeformImporter.normalizeCommand("sh ~/.config/yabai/scripts/focusWindow.sh left")
        let b = FreeformImporter.normalizeCommand("sh /Users/me/.config/yabai-dockstack/scripts/focusWindow.sh left")
        let c = FreeformImporter.normalizeCommand("sh ${SCRIPTS}/focusWindow.sh left")
        XCTAssertEqual(a, "sh @S@focusWindow.sh left")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, c)
    }

    func testNormalizeLeavesPlainCommandsButCollapsesSpaces() {
        XCTAssertEqual(FreeformImporter.normalizeCommand("yabai -m   window --swap west"),
                       "yabai -m window --swap west")
    }

    func testParseSkhdLineLenientColon() {
        let r = FreeformImporter.parseSkhdLine("cmd - f3: sh ~/.config/yabai/scripts/x.sh")
        XCTAssertEqual(r?.hotkey, Hotkey(mods: [.cmd], key: "f3"))
        XCTAssertEqual(r?.command, "sh ~/.config/yabai/scripts/x.sh")
    }

    func testParseSkhdLineRejectsNonBindings() {
        XCTAssertNil(FreeformImporter.parseSkhdLine("# a comment"))
        XCTAssertNil(FreeformImporter.parseSkhdLine(""))
        XCTAssertNil(FreeformImporter.parseSkhdLine(".load \"other\""))
        XCTAssertNil(FreeformImporter.parseSkhdLine(":: mode @"))
        XCTAssertNil(FreeformImporter.parseSkhdLine("cmd - n : yabai -m space --create && \\"))  // continuation
        XCTAssertNil(FreeformImporter.parseSkhdLine("alt - h"))  // no command
    }
}
