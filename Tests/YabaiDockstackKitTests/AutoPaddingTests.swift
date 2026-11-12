import XCTest
@testable import YabaiDockstackKit

final class AutoPaddingTests: XCTestCase {
    private let original = Paddings(left: 30, right: 30, top: 8)

    func testTargetFollowsIndicatorAndStrip() {
        XCTAssertEqual(AutoPadding.target(original: original, cellSize: 32, stripEnabled: true, stripScale: 0.8),
                       Paddings(left: 34, right: 34, top: 26))
        // Smaller indicators shrink the padding, even below the user's own value.
        XCTAssertEqual(AutoPadding.target(original: original, cellSize: 20, stripEnabled: false, stripScale: 0.8),
                       Paddings(left: 22, right: 22, top: 8))
    }

    func testParseConfigValue() {
        XCTAssertEqual(AutoPadding.parse("12\n"), 12)
        XCTAssertEqual(AutoPadding.parse("12.0"), 12)
        XCTAssertNil(AutoPadding.parse("unknown key"))
        XCTAssertNil(AutoPadding.parse(nil))
    }

    func testRelaunchCommand() {
        XCTAssertEqual(Relauncher.arguments(bundlePath: "/Applications/Y.app", executablePath: "/Applications/Y.app/Contents/MacOS/y"),
                       ["-c", "sleep 0.5; /usr/bin/open -n '/Applications/Y.app'"])
        XCTAssertEqual(Relauncher.arguments(bundlePath: "/tmp/build", executablePath: "/tmp/build/y"),
                       ["-c", "sleep 0.5; '/tmp/build/y' >/dev/null 2>&1 &"])
    }

    /// Fake yabai: every `config <key>` query prints 10; everything is logged.
    private func fakeYabai() throws -> (path: String, log: String) {
        let dir = NSTemporaryDirectory() + "fy-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let log = dir + "/log", path = dir + "/yabai"
        let script = "#!/bin/sh\necho \"$*\" >> \(log)\n[ $# -eq 3 ] && echo 10\nexit 0\n"
        try script.write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return (path, log)
    }

    func testControllerAppliesThenRestores() throws {
        let (path, log) = try fakeYabai()
        let c = AutoPaddingController(client: YabaiClient(yabaiPath: path))
        c.update(enabled: true, cellSize: 32, stripEnabled: true, stripScale: 0.8)
        var calls = try String(contentsOfFile: log, encoding: .utf8)
        XCTAssertTrue(calls.contains("-m config left_padding 34"), calls)
        XCTAssertTrue(calls.contains("-m config top_padding 26"), calls)
        c.update(enabled: false, cellSize: 32, stripEnabled: true, stripScale: 0.8)
        calls = try String(contentsOfFile: log, encoding: .utf8)
        XCTAssertTrue(calls.contains("-m config left_padding 10"), calls)
        XCTAssertTrue(calls.contains("-m config top_padding 10"), calls)
    }

    func testUserOriginalOnlyWhileEnabled() throws {
        let (path, _) = try fakeYabai()
        let c = AutoPaddingController(client: YabaiClient(yabaiPath: path))
        XCTAssertNil(c.userOriginal)
        c.update(enabled: true, cellSize: 32, stripEnabled: true, stripScale: 0.8)
        XCTAssertEqual(c.userOriginal, Paddings(left: 10, right: 10, top: 10))
        c.update(enabled: false, cellSize: 32, stripEnabled: true, stripScale: 0.8)
        XCTAssertNil(c.userOriginal)
    }

    func testConfigDefaultsOff() {
        XCTAssertFalse(AppConfig.defaults.autoPadding)
        XCTAssertFalse(AppConfig.load(from: #"{"style":"flag"}"#.data(using: .utf8)).autoPadding)
    }
}
