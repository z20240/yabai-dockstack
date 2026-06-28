import XCTest
import CoreGraphics
@testable import YabaiDockstackKit

final class CoordinateMapperTests: XCTestCase {
    func testFlipsYAboutPrimaryHeight() {
        let r = YRect(x: 100, y: 50, w: 32, h: 64)
        let c = CoordinateMapper.toCocoa(r, primaryHeight: 1000)
        XCTAssertEqual(c.origin.x, 100)
        XCTAssertEqual(c.origin.y, 1000 - 50 - 64)  // 886
        XCTAssertEqual(c.size.width, 32)
        XCTAssertEqual(c.size.height, 64)
    }

    func testNegativeXSecondaryDisplayPreserved() {
        let r = YRect(x: -1158, y: -1015, w: 100, h: 100)
        let c = CoordinateMapper.toCocoa(r, primaryHeight: 1000)
        XCTAssertEqual(c.origin.x, -1158)
        XCTAssertEqual(c.origin.y, 1000 - (-1015) - 100)  // 1915
    }
}
