import XCTest
@testable import YabaiDockstackKit

final class MenuQuickKeysTests: XCTestCase {
    func testSequenceOrderAndUniqueness() {
        XCTAssertEqual(Array(MenuQuickKeys.sequence.prefix(12)),
                       ["1","2","3","4","5","6","7","8","9","0","a","s"])
        XCTAssertEqual(MenuQuickKeys.sequence.count, 26)
        XCTAssertEqual(Set(MenuQuickKeys.sequence).count, 26)
    }

    func testKeysClamps() {
        XCTAssertEqual(MenuQuickKeys.keys(count: 0), [])
        XCTAssertEqual(MenuQuickKeys.keys(count: 3), ["1","2","3"])
        XCTAssertEqual(MenuQuickKeys.keys(count: 99).count, 26)
        XCTAssertEqual(MenuQuickKeys.keys(count: -1), [])
    }
}
