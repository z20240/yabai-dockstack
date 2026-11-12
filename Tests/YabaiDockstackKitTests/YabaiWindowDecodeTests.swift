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

    func testSkipsClosedWindowsEvenWhenWindowServerRetainsThem() throws {
        let template = try XCTUnwrap(
            (JSONSerialization.jsonObject(with: fixtureData()) as? [[String: Any]])?.first)
        // Matches the stale kitty (zero-sized) and LinearMouse (normal-sized)
        // windows: visibility and geometry alone cannot identify both ghosts.
        let entries: [[String: Any]] = [0.0, 885.0].enumerated().map { index, width in
            var entry = template
            entry["id"] = 2615 + index
            entry["app"] = index == 0 ? "kitty" : "LinearMouse"
            entry["title"] = ""
            entry["has-ax-reference"] = false
            entry["is-visible"] = false
            entry["frame"] = ["x": 10.0, "y": 605.0, "w": width, "h": 620.0]
            return entry
        }
        let data = try JSONSerialization.data(withJSONObject: entries + [template])
        XCTAssertEqual(YabaiWindow.decodeList(data).map(\.id), [try XCTUnwrap(template["id"] as? Int)])
    }

    func testKeepsRealWindowsRegardlessOfVisibilityAndSupportsMissingAXFlag() throws {
        let template = try XCTUnwrap(
            (JSONSerialization.jsonObject(with: fixtureData()) as? [[String: Any]])?.first)
        let states: [[String: Any]] = [
            ["has-ax-reference": true, "is-visible": true],
            ["has-ax-reference": true, "is-visible": false], // another space / occluded
            ["has-ax-reference": true, "is-visible": false, "is-minimized": true],
            ["has-ax-reference": true, "is-visible": false, "is-hidden": true],
            [:] // older yabai, without has-ax-reference
        ]
        let entries = states.enumerated().map { index, state in
            var entry = template
            entry.removeValue(forKey: "has-ax-reference")
            entry["id"] = index + 100
            entry.merge(state) { _, new in new }
            return entry
        }
        let data = try JSONSerialization.data(withJSONObject: entries)
        XCTAssertEqual(YabaiWindow.decodeList(data).map(\.id), [100, 101, 102, 103, 104])
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

    func testIsStickyDecodesAndDefaultsToFalse() {
        let json = """
        [
          {"id":10,"pid":200,"app":"Gather","title":"mini","frame":{"x":0.0,"y":0.0,"w":100.0,"h":100.0},"display":1,"space":2,"stack-index":0,"has-focus":false,"is-sticky":true},
          {"id":11,"pid":201,"app":"Finder","title":"tiled","frame":{"x":0.0,"y":0.0,"w":100.0,"h":100.0},"display":1,"space":1,"stack-index":0,"has-focus":false}
        ]
        """.data(using: .utf8)!
        let wins = YabaiWindow.decodeList(json)
        XCTAssertEqual(wins.first { $0.id == 10 }?.isSticky, true)
        XCTAssertEqual(wins.first { $0.id == 11 }?.isSticky, false)
    }

    func testScratchpadDecodesAndDefaultsToNil() {
        let json = """
        [
          {"id":10,"pid":200,"app":"Spotify","title":"music","scratchpad":"Spotify","frame":{"x":0.0,"y":0.0,"w":100.0,"h":100.0},"display":1,"space":1,"stack-index":0,"has-focus":false},
          {"id":11,"pid":201,"app":"Finder","title":"files","frame":{"x":0.0,"y":0.0,"w":100.0,"h":100.0},"display":1,"space":1,"stack-index":0,"has-focus":false}
        ]
        """.data(using: .utf8)!
        let wins = YabaiWindow.decodeList(json)
        XCTAssertEqual(wins.first { $0.id == 10 }?.scratchpad, "Spotify")
        XCTAssertNil(wins.first { $0.id == 11 }?.scratchpad)
    }
}
