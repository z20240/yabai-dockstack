import XCTest
@testable import YabaiDockstackKit

final class AppConfigTests: XCTestCase {
    func testSkhdManagementRequiresExplicitOptInAndPersistsIndependently() throws {
        XCTAssertFalse(AppConfig.defaults.manageSkhdConfig)
        XCTAssertFalse(AppConfig.load(from: nil).manageSkhdConfig)
        XCTAssertFalse(AppConfig.load(from: Data(#"{"manageYabaiConfig":true}"#.utf8)).manageSkhdConfig)
        var config = AppConfig.defaults
        config.manageSkhdConfig = true
        let loaded = AppConfig.load(from: try JSONEncoder().encode(config))
        XCTAssertTrue(loaded.manageSkhdConfig)
        XCTAssertFalse(loaded.manageYabaiConfig)
        config.manageSkhdConfig = false
        XCTAssertFalse(AppConfig.load(from: try JSONEncoder().encode(config)).manageSkhdConfig)
    }
    func testYabaiManagementRequiresExplicitOptInAndPersists() throws {
        XCTAssertFalse(AppConfig.defaults.manageYabaiConfig)
        XCTAssertFalse(AppConfig.load(from: nil).manageYabaiConfig)
        XCTAssertFalse(AppConfig.load(from: Data(#"{"cellSize":24}"#.utf8)).manageYabaiConfig)
        var config = AppConfig.defaults
        config.manageYabaiConfig = true
        XCTAssertTrue(AppConfig.load(from: try JSONEncoder().encode(config)).manageYabaiConfig)
        config.manageYabaiConfig = false
        XCTAssertFalse(AppConfig.load(from: try JSONEncoder().encode(config)).manageYabaiConfig)
    }
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

    func testIndicatorClickThroughDefaultsOffAndLoads() {
        XCTAssertFalse(AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8)).indicatorClickThrough)
        XCTAssertTrue(AppConfig.load(from: #"{"indicatorClickThrough":true}"#.data(using: .utf8)).indicatorClickThrough)
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
        XCTAssertFalse(c.switcherFollowMove)
        XCTAssertFalse(c.switcherWallpaper)
        XCTAssertEqual(c.switcherWallpaperPath, "")
        XCTAssertEqual(c.switcherWallpaperDarkPath, "")
    }

    func testOldConfigWithoutSwitcherFieldsGetsDefaults() {
        // A pre-switcher config file must load with the new fields defaulted.
        let json = #"{"style":"flag","dockPreview":false}"#.data(using: .utf8)!
        let c = AppConfig.load(from: json)
        XCTAssertEqual(c.style, .flag)
        XCTAssertTrue(c.switcherEnabled)
        XCTAssertEqual(c.switcherHotkeyAll, "alt - tab")
        XCTAssertFalse(c.switcherFollowMove)
        XCTAssertFalse(c.switcherWallpaper)
    }

    func testSwitcherFollowMoveLoads() {
        let json = #"{"switcherFollowMove":true}"#.data(using: .utf8)!
        XCTAssertTrue(AppConfig.load(from: json).switcherFollowMove)
    }

    func testSwitcherWallpaperLoads() {
        let json = #"{"switcherWallpaper":true,"switcherWallpaperPath":"/tmp/wallpaper.heic","switcherWallpaperDarkPath":"/tmp/dark.heic"}"#.data(using: .utf8)!
        let c = AppConfig.load(from: json)
        XCTAssertTrue(c.switcherWallpaper)
        XCTAssertEqual(c.switcherWallpaperPath, "/tmp/wallpaper.heic")
        XCTAssertEqual(c.switcherWallpaperDarkPath, "/tmp/dark.heic")
    }

    func testMenuHoverDefaultsOff() {
        XCTAssertFalse(AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8)).menuOpenOnHover)
    }

    func testWindowStripDefaultsOff() {
        XCTAssertFalse(AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8)).windowStrip)
    }
}
