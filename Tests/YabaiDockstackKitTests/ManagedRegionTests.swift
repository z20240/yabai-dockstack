import XCTest
@testable import YabaiDockstackKit

final class ManagedRegionTests: XCTestCase {
    func testExtractNilWhenNoMarkers() {
        XCTAssertNil(ManagedRegion.extract(from: "echo hi\n"))
    }

    func testAppendWhenAbsentPreservesFreeform() {
        let out = ManagedRegion.replace(in: "echo hi\n", with: "LINE1\nLINE2")
        XCTAssertTrue(out.hasPrefix("echo hi\n"))
        XCTAssertTrue(out.contains(ManagedRegion.beginLine))
        XCTAssertTrue(out.contains("LINE1\nLINE2"))
        XCTAssertTrue(out.contains(ManagedRegion.endLine))
        XCTAssertEqual(ManagedRegion.extract(from: out), "LINE1\nLINE2")
    }

    func testReplaceKeepsBeforeAndAfter() {
        let original = ManagedRegion.replace(in: "BEFORE\n", with: "OLD")
        let withAfter = original + "AFTER\n"
        let updated = ManagedRegion.replace(in: withAfter, with: "NEW")
        XCTAssertTrue(updated.hasPrefix("BEFORE\n"))
        XCTAssertTrue(updated.hasSuffix("AFTER\n"))
        XCTAssertEqual(ManagedRegion.extract(from: updated), "NEW")
        XCTAssertFalse(updated.contains("OLD"))
    }
}
