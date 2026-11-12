import XCTest
@testable import YabaiDockstackKit

final class ConfigPathsTests: XCTestCase {
    func testPicksFirstExisting() throws {
        let dir = NSTemporaryDirectory() + "yst-paths-\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let second = dir + "b"
        FileManager.default.createFile(atPath: second, contents: Data())
        let chosen = ConfigPaths.resolve(candidates: [dir + "a", second], fileManager: .default)
        XCTAssertEqual(chosen, second)
        try? FileManager.default.removeItem(atPath: dir)
    }

    func testFallsBackToFirstWhenNoneExist() {
        let chosen = ConfigPaths.resolve(candidates: ["~/.nope-xyz-1", "~/.nope-xyz-2"], fileManager: .default)
        XCTAssertEqual(chosen, (("~/.nope-xyz-1") as NSString).expandingTildeInPath)
    }

    func testYabaiLookupOrderMatchesYabai() {
        XCTAssertEqual(ConfigPaths.lookupOrder(tool: .yabai, xdgConfigHome: "/x", home: "/h"),
                       ["/x/yabai/yabairc", "/h/.config/yabai/yabairc", "/h/.yabairc"])
        XCTAssertEqual(ConfigPaths.lookupOrder(tool: .skhd, xdgConfigHome: nil, home: "/h"),
                       ["/h/.config/skhd/skhdrc", "/h/.skhdrc"])
    }

    func testAutoDetectPrefersDotConfigOverHomeDotfile() {
        let p = ConfigPaths.autoDetect(tool: .yabai, xdgConfigHome: nil, home: "/h", configFlag: nil,
                                       exists: { $0 == "/h/.yabairc" || $0 == "/h/.config/yabai/yabairc" })
        XCTAssertEqual(p, "/h/.config/yabai/yabairc")
    }

    func testAutoDetectConfigFlagWins() {
        XCTAssertEqual(ConfigPaths.configFlag(inCommandLine: "/opt/homebrew/bin/yabai -c /tmp/my.rc"), "/tmp/my.rc")
        XCTAssertEqual(ConfigPaths.configFlag(inCommandLine: "/opt/homebrew/bin/skhd --config /tmp/s"), "/tmp/s")
        XCTAssertNil(ConfigPaths.configFlag(inCommandLine: "/opt/homebrew/bin/yabai"))
        XCTAssertEqual(ConfigPaths.autoDetect(tool: .yabai, xdgConfigHome: nil, home: "/h",
                                              configFlag: "/tmp/my.rc", exists: { _ in false }), "/tmp/my.rc")
    }

    func testAutoDetectFallsBackToFirstInOrder() {
        XCTAssertEqual(ConfigPaths.autoDetect(tool: .skhd, xdgConfigHome: nil, home: "/h", configFlag: nil,
                                              exists: { _ in false }), "/h/.config/skhd/skhdrc")
    }

    /// T1: the first `-c` across all of the tool's processes, not the first process.
    func testRcDetectorTakesFirstConfigFlagAcrossProcesses() {
        let lines = ["/opt/homebrew/bin/yabai", "/usr/bin/vim /tmp/notes", "/opt/homebrew/bin/yabai -c /tmp/x.rc",
                     "/opt/homebrew/bin/yabai -c /tmp/y.rc", "/opt/homebrew/bin/skhd -c /tmp/s"]
        XCTAssertEqual(RcDetector.configFlag(for: .yabai, commandLines: lines), "/tmp/x.rc")
        XCTAssertEqual(RcDetector.configFlag(for: .skhd, commandLines: lines), "/tmp/s")
        XCTAssertNil(RcDetector.configFlag(for: .skhd, commandLines: ["/opt/homebrew/bin/skhd"]))
    }
}
