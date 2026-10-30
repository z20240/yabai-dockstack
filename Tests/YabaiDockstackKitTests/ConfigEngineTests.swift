import XCTest
@testable import YabaiDockstackKit

final class ConfigEngineTests: XCTestCase {
    func testSkhdManagementOffPreventsCreationImportAndReload() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let s = dir.appendingPathComponent("skhdrc").path
        let e = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                             yabaiConfigPath: s + ".y", skhdConfigPath: s, scriptsDir: "/S")
        XCTAssertFalse(e.manageSkhdConfig)
        XCTAssertThrowsError(try e.saveSkhd([]))
        XCTAssertThrowsError(try e.importSkhd())
        XCTAssertFalse(e.applySkhd().ok)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let original = "cmd - b : yabai -m space --balance\n"
        try original.write(toFile: s, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try e.saveSkhd([]))
        XCTAssertThrowsError(try e.importSkhd())
        XCTAssertEqual(try String(contentsOfFile: s, encoding: .utf8), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: s + ".bak"))
        e.manageYabaiConfig = true
        try e.saveYabai(.defaults)
        XCTAssertFalse(e.manageSkhdConfig)

        e.manageSkhdConfig = true
        XCTAssertEqual(try e.importSkhd(), 1)
        XCTAssertTrue(e.applySkhd().ok)
        let managed = try String(contentsOfFile: s, encoding: .utf8)
        e.manageSkhdConfig = false
        XCTAssertThrowsError(try e.saveSkhd([]))
        XCTAssertThrowsError(try e.importSkhd())
        XCTAssertEqual(try String(contentsOfFile: s, encoding: .utf8), managed)
        XCTAssertTrue(e.loadBindings().contains { $0.enabled })
    }
    func testYabaiManagementOffPreventsCreationImportAndRestart() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let y = dir.appendingPathComponent("yabairc").path
        let e = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                             yabaiConfigPath: y, skhdConfigPath: y + ".s", scriptsDir: "/S")
        XCTAssertFalse(e.manageYabaiConfig)
        XCTAssertThrowsError(try e.saveYabai(.defaults))
        XCTAssertThrowsError(try e.importYabai())
        XCTAssertFalse(e.applyYabai().ok, "Must not run even a successful restart command")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let original = "yabai -m config window_gap 7\n"
        try original.write(toFile: y, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try e.saveYabai(.defaults))
        XCTAssertThrowsError(try e.importYabai())
        XCTAssertEqual(try String(contentsOfFile: y, encoding: .utf8), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: y + ".bak"))
        // The options are independent; keyboard configuration can be opted in separately.
        e.manageSkhdConfig = true
        try e.saveSkhd([])
        XCTAssertTrue(FileManager.default.fileExists(atPath: y + ".s"))

        e.manageYabaiConfig = true
        XCTAssertEqual(try e.importYabai(), 1)
        XCTAssertTrue(e.applyYabai().ok)
        let managed = try String(contentsOfFile: y, encoding: .utf8)
        e.manageYabaiConfig = false
        XCTAssertThrowsError(try e.saveYabai(.defaults))
        XCTAssertThrowsError(try e.importYabai())
        XCTAssertEqual(try String(contentsOfFile: y, encoding: .utf8), managed)
        XCTAssertEqual(e.loadYabaiSettings().gap, 7, "Disabling management must preserve existing content")
    }
    private func engine(_ yPath: String, _ sPath: String) -> ConfigEngine {
        ConfigEngine(yabaiPath: "/bin/true", skhdPath: "/bin/true",
                     yabaiConfigPath: yPath, skhdConfigPath: sPath, scriptsDir: "/S")
    }

    func testYabaiSaveLoadRoundTrip() throws {
        let y = NSTemporaryDirectory() + "yst-eng-y-\(UUID().uuidString).rc"
        let e = engine(y, y + ".s")
        var s = DefaultTemplate.defaultYabaiSettings(); s.gap = 17
        e.manageYabaiConfig = true
        try e.saveYabai(s)
        XCTAssertEqual(e.loadYabaiSettings().gap, 17)
        try? FileManager.default.removeItem(atPath: y)
    }

    func testLoadBindingsReturnsRowPerCatalogAction() throws {
        let s = NSTemporaryDirectory() + "yst-eng-s-\(UUID().uuidString).rc"
        let e = engine(s + ".y", s)
        e.manageSkhdConfig = true
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
        e.manageYabaiConfig = true
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
        e.manageSkhdConfig = true
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
        e.manageSkhdConfig = true
        let n = try e.importSkhd()
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
        e.manageSkhdConfig = true
        XCTAssertEqual(try e.importSkhd(), 0)
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
        e.manageYabaiConfig = true
        XCTAssertEqual(try e.importYabai(), 2)
        let text = try String(contentsOfFile: p, encoding: .utf8)
        XCTAssertTrue(text.contains("# [yabai-dockstack imported] yabai -m config window_gap 7"))
        XCTAssertNotNil(ManagedRegion.extract(from: text))
        XCTAssertEqual(e.loadYabaiSettings().gap, 7)
        XCTAssertTrue(e.loadYabaiSettings().rules.contains { $0.app == "Finder" && $0.mode == .float })
        try? FileManager.default.removeItem(atPath: p)
        try? FileManager.default.removeItem(atPath: p + ".bak")
    }

    func testImportSkhdIsIdempotent() throws {
        let p = NSTemporaryDirectory() + "yst-imp-idem-\(UUID().uuidString).skhdrc"
        try "cmd - f3: sh ~/.config/yabai/scripts/taggleShowHideDesktop.sh\n"
            .write(toFile: p, atomically: true, encoding: .utf8)
        let e = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                             yabaiConfigPath: p + ".y", skhdConfigPath: p,
                             scriptsDir: "/Users/me/.config/yabai-dockstack/scripts")
        e.manageSkhdConfig = true
        XCTAssertEqual(try e.importSkhd(), 1)
        let after1 = try String(contentsOfFile: p, encoding: .utf8)
        e.manageSkhdConfig = true
        XCTAssertEqual(try e.importSkhd(), 0)                 // nothing left to import
        let after2 = try String(contentsOfFile: p, encoding: .utf8)
        XCTAssertEqual(after1, after2)                        // file byte-stable, no double-comment
        try? FileManager.default.removeItem(atPath: p)
        try? FileManager.default.removeItem(atPath: p + ".bak")
    }

    func testImportSkhdRefusesMalformedMarkers() throws {
        let p = NSTemporaryDirectory() + "yst-imp-mal-\(UUID().uuidString).skhdrc"
        // two BEGIN markers, one END => malformed; freeform between must be preserved
        let original = "# >>> yabai-dockstack:managed BEGIN >>>\nFREEFORM-A\n# >>> yabai-dockstack:managed BEGIN >>>\nX\n# <<< yabai-dockstack:managed END <<<\n"
        try original.write(toFile: p, atomically: true, encoding: .utf8)
        let e = ConfigEngine(yabaiPath: "/usr/bin/true", skhdPath: "/usr/bin/true",
                             yabaiConfigPath: p + ".y", skhdConfigPath: p, scriptsDir: "/S")
        e.manageSkhdConfig = true
        XCTAssertThrowsError(try e.importSkhd())
        XCTAssertEqual(try String(contentsOfFile: p, encoding: .utf8), original)  // file untouched
        try? FileManager.default.removeItem(atPath: p)
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
