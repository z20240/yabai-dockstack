import XCTest
@testable import YabaiDockstackKit

final class YabaiClientLiveTests: XCTestCase {
    func testReadLiveStateNilWhenYabaiUnavailable() {
        XCTAssertNil(YabaiClient(yabaiPath: "/usr/bin/false").readLiveState())
        XCTAssertNil(YabaiClient(yabaiPath: "/nonexistent/yabai").readLiveState())
    }

    /// Fake yabai answering the live-state queries.
    private func fakeYabai() throws -> String {
        let dir = NSTemporaryDirectory() + "fyl-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(atPath: dir) }
        let path = dir + "/yabai"
        let script = """
        #!/bin/sh
        case "$*" in
          "-m config layout") echo "bsp" ;;
          "-m config top_padding") echo 12 ;;
          "-m config bottom_padding") echo 14 ;;
          "-m config left_padding") echo 16 ;;
          "-m config right_padding") echo 18 ;;
          "-m config window_gap") echo 6 ;;
          "-m rule --list") echo '[{"app":"Finder","manage":false,"sub-layer":"normal"}]' ;;
        esac
        exit 0
        """
        try script.write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }

    func testReadLiveStateReadsConfigAndRules() throws {
        let live = YabaiClient(yabaiPath: try fakeYabai()).readLiveState()
        XCTAssertEqual(live?.layout, "bsp")
        XCTAssertEqual(live?.top, 12)
        XCTAssertEqual(live?.bottom, 14)
        XCTAssertEqual(live?.left, 16)
        XCTAssertEqual(live?.right, 18)
        XCTAssertEqual(live?.gap, 6)
        XCTAssertEqual(live?.rules.map { $0.windowRule }, [WindowRule(app: "Finder", mode: .float)])
    }
}
