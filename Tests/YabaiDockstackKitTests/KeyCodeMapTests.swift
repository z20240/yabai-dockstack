import XCTest
@testable import YabaiDockstackKit

final class KeyCodeMapTests: XCTestCase {
    func testNamedKeys() {
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x7B, chars: nil), "left")
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x7C, chars: nil), "right")
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x7E, chars: nil), "up")
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x7D, chars: nil), "down")
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x31, chars: " "), "space")
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x33, chars: nil), "backspace")
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x63, chars: nil), "f3")
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x74, chars: nil), "pageup")
    }

    func testLetterAndDigitUseChars() {
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x0F, chars: "r"), "r")
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x12, chars: "1"), "1")
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x0F, chars: "R"), "r") // lowercased
    }

    func testFallbackToHexForUnknown() {
        // 0x2A is backslash/section on some layouts; chars not a-z0-9 → hex fallback
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x2A, chars: "|"), "0x2A")
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x2A, chars: nil), "0x2A")
    }

    func testCommaKeyEmitsUppercaseHex() {
        // 0x2B is comma; chars is "," → hex fallback with uppercase (skhd requirement)
        XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: 0x2B, chars: ","), "0x2B")
    }

    func testReverseNamedKeys() {
        XCTAssertEqual(KeyCodeMap.keyCode(forSkhdKey: "tab"), 0x30)
        XCTAssertEqual(KeyCodeMap.keyCode(forSkhdKey: "left"), 0x7B)
        XCTAssertEqual(KeyCodeMap.keyCode(forSkhdKey: "space"), 0x31)
    }

    func testReverseLettersAndDigits() {
        XCTAssertEqual(KeyCodeMap.keyCode(forSkhdKey: "a"), 0x00)
        XCTAssertEqual(KeyCodeMap.keyCode(forSkhdKey: "W"), 0x0D)  // case-insensitive
        XCTAssertEqual(KeyCodeMap.keyCode(forSkhdKey: "1"), 0x12)
    }

    func testReverseHexLiteral() {
        XCTAssertEqual(KeyCodeMap.keyCode(forSkhdKey: "0x32"), 0x32)
        XCTAssertEqual(KeyCodeMap.keyCode(forSkhdKey: "0x2B"), 0x2B)
        XCTAssertNil(KeyCodeMap.keyCode(forSkhdKey: "0xZZ"))
        XCTAssertNil(KeyCodeMap.keyCode(forSkhdKey: "bogus"))
    }

    func testReverseRoundTripsForwardMap() {
        // Every named key must round-trip: name -> code -> name.
        for name in ["left", "right", "down", "up", "space", "return", "tab", "escape",
                     "backspace", "delete", "home", "end", "pageup", "pagedown", "f1", "f12"] {
            guard let code = KeyCodeMap.keyCode(forSkhdKey: name) else {
                XCTFail("no keycode for \(name)"); continue
            }
            XCTAssertEqual(KeyCodeMap.skhdKey(forKeyCode: code, chars: nil), name)
        }
    }
}
