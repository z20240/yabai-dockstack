import XCTest
@testable import YabaiStacklineKit

final class YabaiWindowDecodeTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = Bundle.module.url(forResource: "query-sample", withExtension: "json", subdirectory: "Fixtures")!
        return try Data(contentsOf: url)
    }

    func testDecodesValidWindowsAndSkipsMalformed() throws {
        let wins = YabaiWindow.decodeList(try fixtureData())
        // entry id=4 is malformed (missing fields) -> skipped
        XCTAssertEqual(wins.count, 3)
        let code = wins.first { $0.id == 1 }!
        XCTAssertEqual(code.app, "Code")
        XCTAssertEqual(code.stackIndex, 1)
        XCTAssertTrue(code.hasFocus)
        XCTAssertEqual(code.title, "projA — main.ts — Visual Studio Code")
        XCTAssertEqual(code.frame.w, 800.0)
    }
}
