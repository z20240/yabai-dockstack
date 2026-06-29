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
