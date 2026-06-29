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
}
