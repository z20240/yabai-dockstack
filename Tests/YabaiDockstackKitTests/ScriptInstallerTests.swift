import XCTest
@testable import YabaiDockstackKit

final class ScriptInstallerTests: XCTestCase {
    func testInstallsAllScriptsExecutable() throws {
        let dir = NSTemporaryDirectory() + "yst-scripts-\(UUID().uuidString)/"
        try ScriptInstaller.install(to: dir)
        for name in ScriptInstaller.scriptNames {
            let p = dir + name
            XCTAssertTrue(FileManager.default.fileExists(atPath: p), "missing \(name)")
            let perms = try FileManager.default.attributesOfItem(atPath: p)[.posixPermissions] as? NSNumber
            XCTAssertEqual((perms?.int16Value ?? 0) & 0o111, 0o111, "\(name) not executable")
        }
        try? FileManager.default.removeItem(atPath: dir)
    }

    func testNeedsUpdateDetectsMissingAndStaleScripts() throws {
        let dir = NSTemporaryDirectory() + "yst-scripts-update-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: dir) }

        XCTAssertTrue(ScriptInstaller.needsUpdate(dir: dir))          // nothing installed
        try ScriptInstaller.install(to: dir)
        XCTAssertFalse(ScriptInstaller.needsUpdate(dir: dir))         // fresh install
        try "stale".write(toFile: dir + "/moveWindowToSpace.sh",
                          atomically: true, encoding: .utf8)
        XCTAssertTrue(ScriptInstaller.needsUpdate(dir: dir))          // content drift
    }
}
