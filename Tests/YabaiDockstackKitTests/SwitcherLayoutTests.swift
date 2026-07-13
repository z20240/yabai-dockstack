import XCTest
@testable import YabaiDockstackKit

final class SwitcherLayoutTests: XCTestCase {
    func testFewWindowsKeepBaseSizeOneRow() {
        let g = SwitcherLayout.grid(count: 3, maxWidth: 1600, maxHeight: 800)
        XCTAssertEqual(g.columns, 3)
        XCTAssertEqual(g.rows, 1)
        XCTAssertEqual(g.cellWidth, 240)
    }

    func testColumnsNeverExceedCount() {
        let g = SwitcherLayout.grid(count: 2, maxWidth: 3000, maxHeight: 900)
        XCTAssertEqual(g.columns, 2)
    }

    func testManyWindowsWrapAndShrink() {
        let g = SwitcherLayout.grid(count: 40, maxWidth: 1200, maxHeight: 600)
        XCTAssertGreaterThan(g.rows, 1)
        XCTAssertLessThan(g.cellWidth, 240)
        XCTAssertGreaterThanOrEqual(g.cellWidth, 128)
        // The chosen grid actually holds all cells.
        XCTAssertGreaterThanOrEqual(g.columns * g.rows, 40)
    }

    func testGridFitsWithinBoundsWhenNotAtMinimum() {
        let maxW = 1400.0, maxH = 700.0
        let g = SwitcherLayout.grid(count: 12, maxWidth: maxW, maxHeight: maxH)
        let width = Double(min(12, g.columns)) * (g.cellWidth + 10) - 10
        XCTAssertLessThanOrEqual(width, maxW)
        if g.cellWidth > 128 {  // didn't bottom out → height must fit too
            let height = Double(g.rows) * (g.cellHeight + 10) - 10
            XCTAssertLessThanOrEqual(height, maxH)
        }
    }

    func testZeroCountTreatedAsOne() {
        let g = SwitcherLayout.grid(count: 0, maxWidth: 800, maxHeight: 400)
        XCTAssertEqual(g.columns, 1)
        XCTAssertEqual(g.rows, 1)
    }

    func testCellHeightFormula() {
        XCTAssertEqual(SwitcherLayout.cellHeight(width: 240), 150 + 24)
    }
}
