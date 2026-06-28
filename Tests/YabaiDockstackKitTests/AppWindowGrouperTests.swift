import XCTest
@testable import YabaiDockstackKit

final class AppWindowGrouperTests: XCTestCase {
    private func w(_ id: Int, _ app: String, space: Int, idx: Int) -> YabaiWindow {
        YabaiWindow(id: id, pid: id, app: app, title: "t",
                    frame: YRect(x: 0, y: 0, w: 1, h: 1),
                    display: 1, space: space, stackIndex: idx, hasFocus: false)
    }

    func testFiltersByAppAndSorts() {
        let wins = [
            w(3, "Cursor", space: 10, idx: 1),
            w(1, "Cursor", space: 2, idx: 2),
            w(2, "Cursor", space: 2, idx: 1),
            w(9, "Safari", space: 2, idx: 1),
        ]
        let r = AppWindowGrouper.windows(of: "Cursor", in: wins).map { $0.id }
        XCTAssertEqual(r, [2, 1, 3])   // space 2 (idx1, idx2) then space 10
    }

    func testEmptyWhenNoMatch() {
        XCTAssertTrue(AppWindowGrouper.windows(of: "Nope", in: []).isEmpty)
    }
}
