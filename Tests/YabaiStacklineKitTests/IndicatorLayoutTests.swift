import XCTest
@testable import YabaiStacklineKit

final class IndicatorLayoutTests: XCTestCase {
    let screen = YRect(x: 0, y: 0, w: 1600, h: 1000)

    func testLeftWindowPlacesOnLeftEdge() {
        let stack = YRect(x: 100, y: 50, w: 600, h: 800)  // center x=400 < 800 -> left
        let p = IndicatorLayout.place(stackFrame: stack, screenFrame: screen, cellSize: 32, count: 2, offset: 4)
        XCTAssertEqual(p.side, .left)
        XCTAssertEqual(p.panel.x, 100 - 32 - 4)  // left edge minus width minus offset
        XCTAssertEqual(p.panel.y, 50)
        XCTAssertEqual(p.panel.w, 32)
        XCTAssertEqual(p.panel.h, 64)            // 32 * 2
    }

    func testRightWindowPlacesOnRightEdge() {
        let stack = YRect(x: 900, y: 50, w: 600, h: 800)  // center x=1200 > 800 -> right
        let p = IndicatorLayout.place(stackFrame: stack, screenFrame: screen, cellSize: 32, count: 3, offset: 4)
        XCTAssertEqual(p.side, .right)
        XCTAssertEqual(p.panel.x, 900 + 600 + 4)  // right edge plus offset
        XCTAssertEqual(p.panel.h, 96)
    }

    func testClampsWithinScreen() {
        let stack = YRect(x: 0, y: 50, w: 1600, h: 800)  // spans full width, center=800 -> left
        let p = IndicatorLayout.place(stackFrame: stack, screenFrame: screen, cellSize: 32, count: 1, offset: 4)
        XCTAssertGreaterThanOrEqual(p.panel.x, screen.x)
    }
}
