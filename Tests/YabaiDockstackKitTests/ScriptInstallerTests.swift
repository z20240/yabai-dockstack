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
}
