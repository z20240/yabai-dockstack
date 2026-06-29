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
}
