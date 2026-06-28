import XCTest
@testable import YabaiDockstackKit

final class SmokeTests: XCTestCase {
    func testVersionString() {
        XCTAssertTrue(YabaiDockstack.versionString().contains("yabai-dockstack"))
    }
}
