import XCTest
@testable import YabaiDockstackKit

final class SwitcherModelTests: XCTestCase {
    private func win(_ id: Int, _ app: String, space: Int = 1, stackIndex: Int = 0,
                     title: String = "", focus: Bool = false, visible: Bool = true) -> YabaiWindow {
        YabaiWindow(id: id, pid: id * 10, app: app, title: title.isEmpty ? app : title,
                    frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: space,
                    stackIndex: stackIndex, hasFocus: focus, isVisible: visible)
    }

    func testMRUOrderWinsOverSpaceOrder() {
        let wins = [win(1, "A", space: 1), win(2, "B", space: 2), win(3, "C", space: 3)]
        let items = SwitcherModel.build(windows: wins, mru: [3, 1], scope: .allWindows)
        XCTAssertEqual(items.map { $0.id }, [3, 1, 2])  // MRU first, then unseen by space
    }

    func testUnseenWindowsSortBySpaceStackId() {
        let wins = [win(5, "E", space: 2, stackIndex: 2), win(4, "D", space: 2, stackIndex: 1),
                    win(9, "X", space: 1)]
        let items = SwitcherModel.build(windows: wins, mru: [], scope: .allWindows)
        XCTAssertEqual(items.map { $0.id }, [9, 4, 5])
    }

    func testCurrentAppScopeUsesFocusedWindow() {
        let wins = [win(1, "Cursor", focus: true), win(2, "Cursor", space: 3),
                    win(3, "Safari")]
        let items = SwitcherModel.build(windows: wins, mru: [1], scope: .currentApp)
        XCTAssertEqual(Set(items.map { $0.id }), [1, 2])
    }

    func testCurrentAppScopeFallsBackToMRUAnchor() {
        // Nothing focused (e.g. desktop click) → anchor on the most recent window.
        let wins = [win(1, "Cursor"), win(2, "Cursor", space: 3), win(3, "Safari")]
        let items = SwitcherModel.build(windows: wins, mru: [2, 3], scope: .currentApp)
        XCTAssertEqual(Set(items.map { $0.id }), [1, 2])
    }

    func testCurrentSpaceScope() {
        let wins = [win(1, "A", space: 2, focus: true), win(2, "B", space: 2), win(3, "C", space: 5)]
        let items = SwitcherModel.build(windows: wins, mru: [1], scope: .currentSpace)
        XCTAssertEqual(Set(items.map { $0.id }), [1, 2])
    }

    func testCurrentSpaceScopeWithoutAnchorKeepsVisible() {
        let wins = [win(1, "A", visible: true), win(2, "B", space: 4, visible: false)]
        let items = SwitcherModel.build(windows: wins, mru: [], scope: .currentSpace)
        XCTAssertEqual(items.map { $0.id }, [1])
    }

    func testQueryMatchesAppAndTitleCaseInsensitive() {
        let wins = [win(1, "Cursor", title: "proj — main.swift"),
                    win(2, "Safari", title: "News"),
                    win(3, "Terminal", title: "cursor logs")]
        let items = SwitcherModel.build(windows: wins, mru: [], scope: .allWindows, query: "CURS")
        XCTAssertEqual(Set(items.map { $0.id }), [1, 3])
    }

    func testEmptyQueryAfterTrimKeepsAll() {
        let wins = [win(1, "A"), win(2, "B")]
        XCTAssertEqual(SwitcherModel.build(windows: wins, mru: [], scope: .allWindows,
                                           query: "  ").count, 2)
    }

    func testInitialIndex() {
        XCTAssertEqual(SwitcherModel.initialIndex(count: 0, firstHasFocus: false, backward: false), 0)
        XCTAssertEqual(SwitcherModel.initialIndex(count: 1, firstHasFocus: true, backward: false), 0)
        // Classic alt-tab: land on the previous window when the front is focused.
        XCTAssertEqual(SwitcherModel.initialIndex(count: 3, firstHasFocus: true, backward: false), 1)
        XCTAssertEqual(SwitcherModel.initialIndex(count: 3, firstHasFocus: false, backward: false), 0)
        XCTAssertEqual(SwitcherModel.initialIndex(count: 3, firstHasFocus: true, backward: true), 2)
    }

    func testItemCarriesMetadata() {
        let items = SwitcherModel.build(windows: [win(7, "App", space: 4, title: "t", focus: true)],
                                        mru: [], scope: .allWindows)
        XCTAssertEqual(items.first?.pid, 70)
        XCTAssertEqual(items.first?.space, 4)
        XCTAssertEqual(items.first?.hasFocus, true)
    }
}
