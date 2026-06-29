import XCTest
@testable import YabaiDockstackKit

final class YabaiManagedConfigTests: XCTestCase {
    func testRoundTrip() {
        var s = YabaiSettings.defaults
        s.layout = .bsp
        s.topPadding = 12; s.bottomPadding = 10; s.leftPadding = 24; s.rightPadding = 20; s.gap = 8
        s.rules = [WindowRule(app: "Finder", mode: .float),
                   WindowRule(app: "iTerm2", mode: .manage)]
        let text = YabaiManagedConfig.generate(s)
        XCTAssertTrue(text.contains("yabai -m config layout bsp"))
        XCTAssertTrue(text.contains("yabai -m config top_padding 12"))
        XCTAssertTrue(text.contains(#"yabai -m rule --add app="Finder" manage=off sub-layer=normal"#))
        XCTAssertTrue(text.contains(#"yabai -m rule --add app="iTerm2" manage=on sub-layer=normal"#))
        XCTAssertEqual(YabaiManagedConfig.parse(text), s)
    }

    func testLayoutOffUsesCommentSentinel() {
        var s = YabaiSettings.defaults; s.layout = .off
        let text = YabaiManagedConfig.generate(s)
        XCTAssertTrue(text.contains("# dockstack:layout-off"))
        XCTAssertFalse(text.contains("yabai -m config layout "))
        XCTAssertEqual(YabaiManagedConfig.parse(text).layout, .off)
    }

    func testParseMissingFallsBackToDefaults() {
        let s = YabaiManagedConfig.parse("")
        XCTAssertEqual(s, YabaiSettings.defaults)
    }

    // Fix D: .float layout round-trip
    func testFloatLayoutRoundTrip() {
        var s = YabaiSettings.defaults
        s.layout = .float
        XCTAssertEqual(YabaiManagedConfig.parse(YabaiManagedConfig.generate(s)), s)
    }
}
