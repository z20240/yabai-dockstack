import XCTest
@testable import YabaiDockstackKit

final class ConfigFileWriterTests: XCTestCase {
    private func tmp() -> String { NSTemporaryDirectory() + "yst-writer-\(UUID().uuidString).rc" }

    func testWritePreservesFreeformAndBacksUp() throws {
        let path = tmp()
        try "echo freeform\n".write(toFile: path, atomically: true, encoding: .utf8)
        let w = ConfigFileWriter(path: path)
        try w.writeManagedRegion("LINE1")
        let out = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(out.contains("echo freeform"))
        XCTAssertEqual(ManagedRegion.extract(from: out), "LINE1")
        let bak = try String(contentsOfFile: w.backupPath, encoding: .utf8)
        XCTAssertEqual(bak, "echo freeform\n")
        try? FileManager.default.removeItem(atPath: path)
        try? FileManager.default.removeItem(atPath: w.backupPath)
    }

    func testSecondWriteReplacesRegionNotAppend() throws {
        let path = tmp()
        let w = ConfigFileWriter(path: path)
        try w.writeManagedRegion("OLD")
        try w.writeManagedRegion("NEW")
        let out = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertEqual(ManagedRegion.extract(from: out), "NEW")
        XCTAssertFalse(out.contains("OLD"))
        try? FileManager.default.removeItem(atPath: path)
        try? FileManager.default.removeItem(atPath: w.backupPath)
    }

    func testRestoreBackup() throws {
        let path = tmp()
        try "original\n".write(toFile: path, atomically: true, encoding: .utf8)
        let w = ConfigFileWriter(path: path)
        try w.writeManagedRegion("X")
        try w.restoreBackup()
        let out = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertEqual(out, "original\n")
        try? FileManager.default.removeItem(atPath: path)
        try? FileManager.default.removeItem(atPath: w.backupPath)
    }
}
