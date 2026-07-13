import XCTest
@testable import YabaiDockstackKit

final class MRUOrderTests: XCTestCase {
    func testTouchMovesToFront() {
        var m = MRUOrder()
        m.touch(1); m.touch(2); m.touch(3)
        XCTAssertEqual(m.ids, [3, 2, 1])
        m.touch(1)
        XCTAssertEqual(m.ids, [1, 3, 2])
    }

    func testTouchFrontIsNoop() {
        var m = MRUOrder(ids: [5, 4])
        m.touch(5)
        XCTAssertEqual(m.ids, [5, 4])
    }

    func testPruneDropsDeadWindows() {
        var m = MRUOrder(ids: [3, 2, 1])
        m.prune(keeping: [1, 3])
        XCTAssertEqual(m.ids, [3, 1])
    }

    func testPruneEmptyKeepsNothing() {
        var m = MRUOrder(ids: [1, 2])
        m.prune(keeping: [])
        XCTAssertEqual(m.ids, [])
    }
}
