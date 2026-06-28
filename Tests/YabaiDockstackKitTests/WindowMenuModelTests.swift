import XCTest
@testable import YabaiDockstackKit

final class WindowMenuModelTests: XCTestCase {
    private func win(_ id: Int, app: String, display: Int, space: Int, idx: Int, focus: Bool = false) -> YabaiWindow {
        YabaiWindow(id: id, pid: id * 10, app: app, title: "\(app)-win",
                    frame: YRect(x: 0, y: 0, w: 1, h: 1),
                    display: display, space: space, stackIndex: idx, hasFocus: focus)
    }

    func testGroupsByDisplayThenSpaceSortedWithStackOrder() {
        let wins = [
            win(3, app: "C", display: 2, space: 5, idx: 1),
            win(1, app: "A", display: 1, space: 1, idx: 2),
            win(2, app: "B", display: 1, space: 1, idx: 1, focus: true),
        ]
        let groups = WindowMenuModel.build(wins)
        XCTAssertEqual(groups.map { $0.display }, [1, 2])           // displays sorted
        XCTAssertEqual(groups[0].spaces[0].space, 1)
        // within a space, ordered by stack index
        XCTAssertEqual(groups[0].spaces[0].windows.map { $0.id }, [2, 1])
        XCTAssertTrue(groups[0].spaces[0].windows[0].focused)
        XCTAssertEqual(groups[1].display, 2)
        XCTAssertEqual(groups[1].spaces[0].windows[0].app, "C")
    }

    func testEntryCarriesPidForIcon() {
        let groups = WindowMenuModel.build([win(7, app: "X", display: 1, space: 1, idx: 1)])
        XCTAssertEqual(groups[0].spaces[0].windows[0].pid, 70)
    }

    func testSpaceNameUsesLabelWhenPresentElseIndex() {
        let wins = [
            win(1, app: "A", display: 1, space: 1, idx: 1),
            win(2, app: "B", display: 1, space: 2, idx: 1),
        ]
        let groups = WindowMenuModel.build(wins, spaceLabels: [1: "work"])
        XCTAssertEqual(groups[0].spaces[0].name, "work")     // labeled
        XCTAssertEqual(groups[0].spaces[1].name, "Space 2")  // unlabeled -> index
    }
}
