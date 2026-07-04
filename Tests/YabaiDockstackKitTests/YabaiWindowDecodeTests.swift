import XCTest
@testable import YabaiDockstackKit

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

    func testIsFloatingDecodesAndDefaultsToFalse() throws {
        let json = """
        [
          {"id":10,"pid":200,"app":"Finder","title":"floaty","frame":{"x":0.0,"y":0.0,"w":100.0,"h":100.0},"display":1,"space":1,"stack-index":0,"has-focus":false,"is-floating":true},
          {"id":11,"pid":201,"app":"Finder","title":"tiled","frame":{"x":0.0,"y":0.0,"w":100.0,"h":100.0},"display":1,"space":1,"stack-index":0,"has-focus":false}
        ]
        """.data(using: .utf8)!
        let wins = YabaiWindow.decodeList(json)
        XCTAssertEqual(wins.count, 2)
        XCTAssertEqual(wins.first { $0.id == 10 }?.isFloating, true)
        XCTAssertEqual(wins.first { $0.id == 11 }?.isFloating, false)
    }
}
