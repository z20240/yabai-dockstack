import XCTest
@testable import YabaiStacklineKit

final class RefreshDiffTests: XCTestCase {
    private func stack(_ key: String, ids: [Int], focused: Bool) -> Stack {
        let wins = ids.map { YabaiWindow(id: $0, pid: $0, app: "A", title: "t",
            frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 1,
            stackIndex: $0, hasFocus: focused && $0 == ids.first) }
        return Stack(frame: YRect(x: 0, y: 0, w: 1, h: 1), display: 1, space: 1,
                     windows: wins, isFocused: focused, key: key)
    }

    func testNoChange() {
        let a = [stack("k", ids: [1,2], focused: true)]
        XCTAssertFalse(RefreshDiff.shouldRedraw(old: a, new: a))
    }
    func testFocusChange() {
        let a = [stack("k", ids: [1,2], focused: true)]
        let b = [stack("k", ids: [1,2], focused: false)]
        XCTAssertTrue(RefreshDiff.shouldRedraw(old: a, new: b))
    }
    func testMembershipChange() {
        let a = [stack("k", ids: [1,2], focused: true)]
        let b = [stack("k", ids: [1,2,3], focused: true)]
        XCTAssertTrue(RefreshDiff.shouldRedraw(old: a, new: b))
    }
}
