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

    func testFloatModeFloatsAllWindows() {
        // Float = float layout + global manage=off catch-all (last, so it wins) so
        // every window's is-floating is true and the floating-mode shortcuts apply.
        var s = YabaiSettings.defaults; s.layout = .float
        s.rules = [WindowRule(app: "Finder", mode: .float)]
        let text = YabaiManagedConfig.generate(s)
        XCTAssertTrue(text.contains("yabai -m config layout float"))
        XCTAssertTrue(text.contains(#"yabai -m rule --add app=".*" manage=off sub-layer=normal"#))
        XCTAssertTrue(text.contains("yabai -m rule --apply"))
        XCTAssertFalse(text.contains("# dockstack:layout-off"))
        // Round-trip recovers .float + the real rule, NOT the synthetic .* rule.
        XCTAssertEqual(YabaiManagedConfig.parse(text), s)
        XCTAssertEqual(YabaiManagedConfig.parse(text).rules, [WindowRule(app: "Finder", mode: .float)])
    }

    func testOffModeIsBareFloatLayout() {
        // Off = native feel: float the layout, leave windows untouched (NO catch-all).
        var s = YabaiSettings.defaults; s.layout = .off
        s.rules = [WindowRule(app: "Finder", mode: .float)]
        let text = YabaiManagedConfig.generate(s)
        XCTAssertTrue(text.contains("# dockstack:layout-off"))
        XCTAssertTrue(text.contains("yabai -m config layout float"))
        XCTAssertFalse(text.contains(#"app=".*""#))   // no synthetic catch-all in Off
        XCTAssertEqual(YabaiManagedConfig.parse(text), s)
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
