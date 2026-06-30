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

    func testParseSkhdLinePreservesColonInCommand() {
        let r = FreeformImporter.parseSkhdLine("shift + cmd - g : yabai -m window --grid 2:2:0:0:1:1")
        XCTAssertEqual(r?.command, "yabai -m window --grid 2:2:0:0:1:1")
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

extension FreeformImporterTests {
    func testImportSkhdMatchesAndComments() {
        let file = """
        cmd - f3: sh ~/.config/yabai/scripts/taggleShowHideDesktop.sh
        cmd - x : yabai -m space --create && jq something
        # >>> yabai-dockstack:managed BEGIN >>>
        cmd - 4 : sh /Users/me/.config/yabai-dockstack/scripts/taggleShowHideDesktop.sh
        # <<< yabai-dockstack:managed END <<<
        """
        let current = [ShortcutBinding(actionID: "toggle-show-desktop", enabled: true,
                                       hotkey: Hotkey(mods: [.cmd], key: "4"))]
        let r = FreeformImporter.importSkhd(fileText: file, current: current,
                                            catalog: ShortcutCatalog.all, scriptsDir: "/Users/me/.config/yabai-dockstack/scripts")
        XCTAssertEqual(r.importedCount, 1)
        // imported value wins: toggle-show-desktop now bound to cmd - f3
        XCTAssertEqual(r.bindings.first { $0.actionID == "toggle-show-desktop" }?.hotkey,
                       Hotkey(mods: [.cmd], key: "f3"))
        // freeform line commented; the jq line and the managed region untouched
        XCTAssertTrue(r.newText.contains("# [yabai-dockstack imported] cmd - f3: sh ~/.config/yabai/scripts/taggleShowHideDesktop.sh"))
        XCTAssertTrue(r.newText.contains("cmd - x : yabai -m space --create && jq something"))
        XCTAssertTrue(r.newText.contains("cmd - 4 : sh /Users/me/.config/yabai-dockstack/scripts/taggleShowHideDesktop.sh"))
    }

    func testImportSkhdNothingToImport() {
        let file = "cmd - z : some-custom-thing\n"
        let r = FreeformImporter.importSkhd(fileText: file, current: [],
                                            catalog: ShortcutCatalog.all, scriptsDir: "/S")
        XCTAssertEqual(r.importedCount, 0)
        XCTAssertEqual(r.newText, file)
    }
}

extension FreeformImporterTests {
    func testImportYabaiConfigAndRules() {
        let file = """
        sudo yabai --load-sa
        yabai -m config layout bsp
        yabai -m config top_padding 8
        yabai -m config window_gap 6
        yabai -m rule --add app="Finder" manage=off sub-layer=normal
        yabai -m rule --add app=".*" sub-layer=normal
        yabai -m rule --apply
        echo done
        """
        let r = FreeformImporter.importYabai(fileText: file, current: YabaiSettings.defaults)
        XCTAssertEqual(r.settings.layout, .bsp)
        XCTAssertEqual(r.settings.topPadding, 8)
        XCTAssertEqual(r.settings.gap, 6)
        XCTAssertEqual(r.settings.rules, [WindowRule(app: "Finder", mode: .float)]) // .* skipped
        XCTAssertEqual(r.importedCount, 4) // layout, top_padding, gap, Finder rule
        XCTAssertTrue(r.newText.contains("# [yabai-dockstack imported] yabai -m config top_padding 8"))
        XCTAssertTrue(r.newText.contains("sudo yabai --load-sa"))         // untouched
        XCTAssertTrue(r.newText.contains("yabai -m rule --apply"))        // untouched
        XCTAssertTrue(r.newText.contains("echo done"))                   // untouched
        XCTAssertTrue(r.newText.contains(#"yabai -m rule --add app=".*" sub-layer=normal"#)) // .* untouched
    }
}
