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

    // Fix C: hasMalformedMarkers
    func testHasMalformedMarkersEmptyAndClean() {
        XCTAssertFalse(ManagedRegion.hasMalformedMarkers(in: ""), "empty -> false")
        XCTAssertFalse(ManagedRegion.hasMalformedMarkers(in: "echo hi\nno markers\n"), "no markers -> false")
        let clean = ManagedRegion.replace(in: "", with: "BODY")
        XCTAssertFalse(ManagedRegion.hasMalformedMarkers(in: clean), "one ordered pair -> false")
    }

    func testHasMalformedMarkersDetectsDuplicateBegin() {
        let twoBegins = ManagedRegion.beginLine + "\nFREEFORM-A\n" + ManagedRegion.beginLine + "\nX\n" + ManagedRegion.endLine + "\n"
        XCTAssertTrue(ManagedRegion.hasMalformedMarkers(in: twoBegins), "two BEGIN lines -> true")
    }

    func testHasMalformedMarkersDetectsEndBeforeBegin() {
        let endFirst = ManagedRegion.endLine + "\n" + ManagedRegion.beginLine + "\n"
        XCTAssertTrue(ManagedRegion.hasMalformedMarkers(in: endFirst), "END before BEGIN -> true")
    }

    func testWriteManagedRegionThrowsAndPreservesFreeformOnMalformedMarkers() throws {
        let path = tmp()
        defer {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: ConfigFileWriter(path: path).backupPath)
        }
        let malformed = ManagedRegion.beginLine + "\nFREEFORM-A\n" + ManagedRegion.beginLine + "\nX\n" + ManagedRegion.endLine + "\n"
        try malformed.write(toFile: path, atomically: true, encoding: .utf8)
        let w = ConfigFileWriter(path: path)
        XCTAssertThrowsError(try w.writeManagedRegion("NEW"), "should throw on malformed markers")
        let after = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(after.contains("FREEFORM-A"), "freeform text must still be present after refused write")
        XCTAssertFalse(FileManager.default.fileExists(atPath: w.backupPath), "no .bak should be created on refused write")
    }

    // Fix D: restoreBackup throws when no backup exists
    func testRestoreBackupThrowsWhenNoBak() {
        let w = ConfigFileWriter(path: tmp())
        XCTAssertThrowsError(try w.restoreBackup(), "should throw when no backup exists")
    }
}
