import XCTest
@testable import YabaiDockstackKit

final class AppConfigTests: XCTestCase {
    func testDefaultsWhenNil() {
        let c = AppConfig.load(from: nil)
        XCTAssertEqual(c.style, .icon)
        XCTAssertEqual(c.cellSize, 32)
        XCTAssertEqual(c.yabaiPath, "/opt/homebrew/bin/yabai")
    }

    func testPartialOverrideMergesOverDefaults() {
        let json = #"{"style":"flag","cellSize":24}"#.data(using: .utf8)!
        let c = AppConfig.load(from: json)
        XCTAssertEqual(c.style, .flag)
        XCTAssertEqual(c.cellSize, 24)
        XCTAssertEqual(c.offset, AppConfig.defaults.offset)  // untouched
    }

    func testDockPreviewDefaultsOn() {
        XCTAssertTrue(AppConfig.defaults.dockPreview)
        XCTAssertTrue(AppConfig.load(from: nil).dockPreview)
    }

    func testGarbageFallsBackToDefaults() {
        let c = AppConfig.load(from: "not json".data(using: .utf8))
        XCTAssertEqual(c, AppConfig.defaults)
    }

    func testSaveAndReloadRoundTrips() throws {
        let tmp = NSTemporaryDirectory() + "yst-config-test.json"
        var c = AppConfig.defaults
        c.style = .flag
        c.save(to: tmp)
        let reloaded = AppConfig.loadFromFile(tmp)
        XCTAssertEqual(reloaded.style, .flag)
        try? FileManager.default.removeItem(atPath: tmp)
    }

    func testLanguageDefaultsToAutoAndRoundTrips() {
        XCTAssertEqual(AppConfig.defaults.language, "auto")
        let json = #"{"language":"ja"}"#.data(using: .utf8)!
        XCTAssertEqual(AppConfig.load(from: json).language, "ja")
    }

    func testSwitcherDefaults() {
        let c = AppConfig.defaults
        XCTAssertTrue(c.switcherEnabled)
        XCTAssertEqual(c.switcherAppearance, "thumbnails")
        XCTAssertTrue(c.switcherHoldToCycle)
        XCTAssertFalse(c.switcherCaptureCmdTab)
        XCTAssertEqual(c.switcherHotkeyAll, "alt - tab")
        XCTAssertEqual(c.switcherHotkeyApp, "alt - 0x32")
        XCTAssertEqual(c.switcherHotkeySpace, "")
    }

    func testOldConfigWithoutSwitcherFieldsGetsDefaults() {
        // A pre-switcher config file must load with the new fields defaulted.
        let json = #"{"style":"flag","dockPreview":false}"#.data(using: .utf8)!
        let c = AppConfig.load(from: json)
        XCTAssertEqual(c.style, .flag)
        XCTAssertTrue(c.switcherEnabled)
        XCTAssertEqual(c.switcherHotkeyAll, "alt - tab")
    }
}
