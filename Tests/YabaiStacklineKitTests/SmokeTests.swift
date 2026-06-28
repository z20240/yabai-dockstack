import XCTest
@testable import YabaiStacklineKit

final class SmokeTests: XCTestCase {
    func testVersionString() {
        XCTAssertTrue(YabaiStackline.versionString().contains("yabai-stackline"))
    }
}
