import XCTest
import AppKit
@testable import YabaiDockstackKit

final class ColorHexTests: XCTestCase {
    func testValidSixDigitHex() {
        let c = NSColor(hex: "#FF0000")?.usingColorSpace(.sRGB)
        XCTAssertNotNil(c)
        XCTAssertEqual(c!.redComponent, 1.0, accuracy: 0.001)
        XCTAssertEqual(c!.greenComponent, 0.0, accuracy: 0.001)
        XCTAssertEqual(c!.blueComponent, 0.0, accuracy: 0.001)
    }

    func testEightDigitHexAlpha() {
        let c = NSColor(hex: "00FF0080")?.usingColorSpace(.sRGB)
        XCTAssertNotNil(c)
        XCTAssertEqual(c!.alphaComponent, 128.0 / 255.0, accuracy: 0.001)
    }

    func testInvalidReturnsNil() {
        XCTAssertNil(NSColor(hex: "nope"))
        XCTAssertNil(NSColor(hex: "#FFF"))
    }

    func testFallback() {
        XCTAssertEqual(NSColor.fromHex("bad", fallback: .systemBlue), .systemBlue)
    }
}
