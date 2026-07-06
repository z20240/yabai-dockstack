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
}
