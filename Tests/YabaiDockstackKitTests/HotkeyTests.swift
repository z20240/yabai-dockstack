import XCTest
@testable import YabaiDockstackKit

final class HotkeyTests: XCTestCase {
    func testParseBasic() {
        let h = Hotkey.parse("alt + cmd - left")
        XCTAssertEqual(h, Hotkey(mods: [.alt, .cmd], key: "left"))
    }

    func testRoundTripCanonicalOrder() {
        let h = Hotkey(mods: [.cmd, .alt, .shift], key: "r")
        XCTAssertEqual(h.skhdString, "shift + alt + cmd - r")
        XCTAssertEqual(Hotkey.parse(h.skhdString), h)
    }

    func testKeycodeKey() {
        let h = Hotkey.parse("alt + cmd - 0x2A")
        XCTAssertEqual(h, Hotkey(mods: [.alt, .cmd], key: "0x2A"))
        XCTAssertEqual(h?.skhdString, "alt + cmd - 0x2A")
    }

    func testNoModifier() {
        let h = Hotkey.parse("cmd - f3")
        XCTAssertEqual(h, Hotkey(mods: [.cmd], key: "f3"))
    }

    func testInvalidReturnsNil() {
        XCTAssertNil(Hotkey.parse("   "))
        XCTAssertNil(Hotkey.parse("cmd -"))
    }

    func testDisplayGlyphs() {
        XCTAssertEqual(Hotkey(mods: [.cmd, .alt], key: "left").displayString, "⌥⌘←")
    }

    func testCommaDisplay() {
        XCTAssertEqual(Hotkey.parse("ctrl - 0x2b")?.displayString, "⌃,")
        XCTAssertEqual(Hotkey.parse("ctrl - 0x2B")?.displayString, "⌃,")
    }
}
