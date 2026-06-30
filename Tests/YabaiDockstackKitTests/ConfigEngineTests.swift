import XCTest
@testable import YabaiDockstackKit

final class ConfigEngineTests: XCTestCase {
    private func engine(_ yPath: String, _ sPath: String) -> ConfigEngine {
        ConfigEngine(yabaiPath: "/bin/true", skhdPath: "/bin/true",
                     yabaiConfigPath: yPath, skhdConfigPath: sPath, scriptsDir: "/S")
    }

    func testYabaiSaveLoadRoundTrip() throws {
        let y = NSTemporaryDirectory() + "yst-eng-y-\(UUID().uuidString).rc"
        let e = engine(y, y + ".s")
        var s = DefaultTemplate.defaultYabaiSettings(); s.gap = 17
        try e.saveYabai(s)
        XCTAssertEqual(e.loadYabaiSettings().gap, 17)
        try? FileManager.default.removeItem(atPath: y)
    }

    func testLoadBindingsReturnsRowPerCatalogAction() throws {
        let s = NSTemporaryDirectory() + "yst-eng-s-\(UUID().uuidString).rc"
        let e = engine(s + ".y", s)
        try e.saveSkhd([ShortcutBinding(actionID: "balance", enabled: true,
                                        hotkey: Hotkey(mods: [.alt, .cmd], key: "0x2A"))])
        let loaded = e.loadBindings()
        XCTAssertEqual(loaded.count, ShortcutCatalog.all.count)
        XCTAssertEqual(loaded.first { $0.actionID == "balance" }?.enabled, true)
        XCTAssertEqual(loaded.first { $0.actionID == "rotate-cw" }?.enabled, false) // not saved -> disabled row
        try? FileManager.default.removeItem(atPath: s)
    }

    func testOrDefaultUsesCuratedDefaultsWhenNoRegion() {
        let y = NSTemporaryDirectory() + "yst-eng-def-\(UUID().uuidString).rc"
        let e = ConfigEngine(yabaiPath: "/bin/true", skhdPath: "/bin/true",
                             yabaiConfigPath: y, skhdConfigPath: y + ".s", scriptsDir: "/S")
        XCTAssertFalse(e.hasYabaiRegion())
        XCTAssertFalse(e.hasSkhdRegion())
        // curated yabai default includes the Finder float rule
        XCTAssertTrue(e.loadYabaiSettingsOrDefault().rules.contains { $0.app == "Finder" && $0.mode == .float })
        // curated default bindings: every catalog action enabled
        let b = e.loadBindingsOrDefault()
        XCTAssertEqual(b.count, ShortcutCatalog.all.count)
        XCTAssertTrue(b.allSatisfy { $0.enabled })
    }

    func testOrDefaultUsesRegionWhenPresent() throws {
        let y = NSTemporaryDirectory() + "yst-eng-reg-\(UUID().uuidString).rc"
        let e = ConfigEngine(yabaiPath: "/bin/true", skhdPath: "/bin/true",
                             yabaiConfigPath: y, skhdConfigPath: y + ".s", scriptsDir: "/S")
        var s = YabaiSettings.defaults; s.gap = 99; s.rules = []
        try e.saveYabai(s)
        XCTAssertTrue(e.hasYabaiRegion())
        XCTAssertEqual(e.loadYabaiSettingsOrDefault().gap, 99)
        XCTAssertTrue(e.loadYabaiSettingsOrDefault().rules.isEmpty) // region wins, not curated default
        try? FileManager.default.removeItem(atPath: y)
    }

    func testLoadBindingsOrDefaultUsesRegionWhenPresent() throws {
        let s = NSTemporaryDirectory() + "yst-eng-skreg-\(UUID().uuidString).rc"
        let e = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                             yabaiConfigPath: s + ".y", skhdConfigPath: s, scriptsDir: "/S")
        try e.saveSkhd([ShortcutBinding(actionID: "balance", enabled: true,
                                        hotkey: Hotkey(mods: [.alt, .cmd], key: "0x2A"))])
        XCTAssertTrue(e.hasSkhdRegion())
        let loaded = e.loadBindingsOrDefault()
        // region present -> reflects the saved single binding among full catalog rows
        XCTAssertEqual(loaded.first { $0.actionID == "balance" }?.enabled, true)
        XCTAssertEqual(loaded.first { $0.actionID == "rotate-cw" }?.enabled, false)
        try? FileManager.default.removeItem(atPath: s)
    }

    func testImportSkhdMigratesFreeformIntoRegion() throws {
        let p = NSTemporaryDirectory() + "yst-imp-\(UUID().uuidString).skhdrc"
        // freeform original binds toggle-show-desktop to cmd - f3 (user's own script path)
        try "cmd - f3: sh ~/.config/yabai/scripts/taggleShowHideDesktop.sh\n"
            .write(toFile: p, atomically: true, encoding: .utf8)
        let e = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                             yabaiConfigPath: p + ".y", skhdConfigPath: p,
                             scriptsDir: "/Users/me/.config/yabai-dockstack/scripts")
        let n = e.importSkhd()
        XCTAssertEqual(n, 1)
        let text = try String(contentsOfFile: p, encoding: .utf8)
        XCTAssertTrue(text.contains("# [yabai-dockstack imported] cmd - f3:"))  // original commented
        XCTAssertNotNil(ManagedRegion.extract(from: text))                       // region created
        // the managed region now binds toggle-show-desktop to cmd - f3
        XCTAssertEqual(e.loadBindings().first { $0.actionID == "toggle-show-desktop" }?.hotkey,
                       Hotkey(mods: [.cmd], key: "f3"))
        try? FileManager.default.removeItem(atPath: p)
        try? FileManager.default.removeItem(atPath: p + ".bak")
    }

    func testImportSkhdNoopWhenNothingMatches() throws {
        let p = NSTemporaryDirectory() + "yst-imp2-\(UUID().uuidString).skhdrc"
        try "cmd - z : my-own-thing\n".write(toFile: p, atomically: true, encoding: .utf8)
        let e = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                             yabaiConfigPath: p + ".y", skhdConfigPath: p, scriptsDir: "/S")
        XCTAssertEqual(e.importSkhd(), 0)
        let text = try String(contentsOfFile: p, encoding: .utf8)
        XCTAssertNil(ManagedRegion.extract(from: text))  // nothing imported -> file unchanged, no region
        XCTAssertEqual(text, "cmd - z : my-own-thing\n")
        try? FileManager.default.removeItem(atPath: p)
    }

    func testImportYabaiMigratesFreeformIntoRegion() throws {
        let p = NSTemporaryDirectory() + "yst-impy-\(UUID().uuidString).yabairc"
        try "yabai -m config window_gap 7\nyabai -m rule --add app=\"Finder\" manage=off sub-layer=normal\n"
            .write(toFile: p, atomically: true, encoding: .utf8)
        let e = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                             yabaiConfigPath: p, skhdConfigPath: p + ".s", scriptsDir: "/S")
        XCTAssertEqual(e.importYabai(), 2)
        let text = try String(contentsOfFile: p, encoding: .utf8)
        XCTAssertTrue(text.contains("# [yabai-dockstack imported] yabai -m config window_gap 7"))
        XCTAssertNotNil(ManagedRegion.extract(from: text))
        XCTAssertEqual(e.loadYabaiSettings().gap, 7)
        XCTAssertTrue(e.loadYabaiSettings().rules.contains { $0.app == "Finder" && $0.mode == .float })
        try? FileManager.default.removeItem(atPath: p)
        try? FileManager.default.removeItem(atPath: p + ".bak")
    }

    /// Fix B: two bindings resolving to the same catalog command must not trap loadBindings().
    func testLoadBindingsDuplicateActionIDDoesNotCrash() throws {
        let s = NSTemporaryDirectory() + "yst-eng-dup-\(UUID().uuidString).rc"
        defer { try? FileManager.default.removeItem(atPath: s) }
        // Build a raw skhd file whose managed region maps two different hotkeys to the same command.
        let body = "alt + cmd - 0x2A : yabai -m space --balance\nctrl - b : yabai -m space --balance"
        let regionText = ManagedRegion.replace(in: "", with: body)
        try regionText.write(toFile: s, atomically: true, encoding: .utf8)
        let e = engine(s + ".y", s)
        let loaded = e.loadBindings()
        XCTAssertEqual(loaded.count, ShortcutCatalog.all.count, "must return one row per catalog action")
        XCTAssertEqual(loaded.first { $0.actionID == "balance" }?.enabled, true, "balance row enabled")
    }
}
