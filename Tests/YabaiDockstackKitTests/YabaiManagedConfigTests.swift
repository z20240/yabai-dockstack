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

    func testLayoutOffTurnsManagementOff() {
        var s = YabaiSettings.defaults; s.layout = .off
        s.rules = [WindowRule(app: "Finder", mode: .float)]
        let text = YabaiManagedConfig.generate(s)
        // Off must actually do something: float layout + a global manage=off catch-all
        // (emitted last so it wins), marked by the sentinel.
        XCTAssertTrue(text.contains("# dockstack:layout-off"))
        XCTAssertTrue(text.contains("yabai -m config layout float"))
        XCTAssertTrue(text.contains(#"yabai -m rule --add app=".*" manage=off sub-layer=normal"#))
        XCTAssertTrue(text.contains("yabai -m rule --apply"))
        // Round-trip: parse recovers .off and the user's real rule, NOT the synthetic .* rule.
        let parsed = YabaiManagedConfig.parse(text)
        XCTAssertEqual(parsed.layout, .off)
        XCTAssertEqual(parsed.rules, [WindowRule(app: "Finder", mode: .float)])
        XCTAssertEqual(parsed, s)
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
