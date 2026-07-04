import XCTest
@testable import YabaiDockstackKit

final class SpaceTravelPlannerTests: XCTestCase {
    // Layout mirrors the design-time machine: d1=[1..5], d2=[6..8], d3=[9..11].
    private let spaces: [SpaceInfo] = [
        .init(index: 1, display: 1, isVisible: false), .init(index: 2, display: 1, isVisible: true),
        .init(index: 3, display: 1, isVisible: false), .init(index: 4, display: 1, isVisible: false),
        .init(index: 5, display: 1, isVisible: false),
        .init(index: 6, display: 2, isVisible: false), .init(index: 7, display: 2, isVisible: true),
        .init(index: 8, display: 2, isVisible: false),
        .init(index: 9, display: 3, isVisible: true), .init(index: 10, display: 3, isVisible: false),
        .init(index: 11, display: 3, isVisible: false),
    ]
    private let displays: [DisplayInfo] = [
        .init(index: 1, frame: YRect(x: 0, y: 0, w: 1728, h: 1117)),
        .init(index: 2, frame: YRect(x: -942, y: -1080, w: 1920, h: 1080)),
        .init(index: 3, frame: YRect(x: 978, y: -1080, w: 1920, h: 1080)),
    ]

    func testNextSameDisplay() {
        let p = SpaceTravelPlanner.plan(target: .next, windowSpace: 2, windowDisplay: 1,
                                        spaces: spaces, displays: displays)
        XCTAssertEqual(p, TravelPlan(steps: [.arrowWalk(direction: .right, count: 1)],
                                     sourceSpace: 2, targetSpace: 3))
    }

    func testPrevSameDisplay() {
        let p = SpaceTravelPlanner.plan(target: .prev, windowSpace: 7, windowDisplay: 2,
                                        spaces: spaces, displays: displays)
        XCTAssertEqual(p, TravelPlan(steps: [.arrowWalk(direction: .left, count: 1)],
                                     sourceSpace: 7, targetSpace: 6))
    }

    func testNextWrapsByWalkingLeftToFirst() {
        // At the right edge (space 5 of d1): next wraps to 1 = walk left 4 times.
        let p = SpaceTravelPlanner.plan(target: .next, windowSpace: 5, windowDisplay: 1,
                                        spaces: spaces, displays: displays)
        XCTAssertEqual(p, TravelPlan(steps: [.arrowWalk(direction: .left, count: 4)],
                                     sourceSpace: 5, targetSpace: 1))
    }

    func testPrevWrapsByWalkingRightToLast() {
        let p = SpaceTravelPlanner.plan(target: .prev, windowSpace: 1, windowDisplay: 1,
                                        spaces: spaces, displays: displays)
        XCTAssertEqual(p, TravelPlan(steps: [.arrowWalk(direction: .right, count: 4)],
                                     sourceSpace: 1, targetSpace: 5))
    }

    func testIndexSameDisplayMultiStep() {
        let p = SpaceTravelPlanner.plan(target: .index(5), windowSpace: 2, windowDisplay: 1,
                                        spaces: spaces, displays: displays)
        XCTAssertEqual(p, TravelPlan(steps: [.arrowWalk(direction: .right, count: 3)],
                                     sourceSpace: 2, targetSpace: 5))
    }

    func testIndexCrossDisplayWalksFromVisibleSpace() {
        // Window on d1; target 8 lives on d2 whose visible space is 7:
        // move to d2 (quarter point of its frame), then walk right once.
        let p = SpaceTravelPlanner.plan(target: .index(8), windowSpace: 2, windowDisplay: 1,
                                        spaces: spaces, displays: displays)
        XCTAssertEqual(p, TravelPlan(
            steps: [.moveToDisplay(display: 2, x: -942 + 1920 / 4, y: -1080 + 1080 / 4),
                    .arrowWalk(direction: .right, count: 1)],
            sourceSpace: 2, targetSpace: 8))
    }

    func testIndexCrossDisplayToVisibleSpaceNeedsNoWalk() {
        let p = SpaceTravelPlanner.plan(target: .index(7), windowSpace: 2, windowDisplay: 1,
                                        spaces: spaces, displays: displays)
        XCTAssertEqual(p, TravelPlan(
            steps: [.moveToDisplay(display: 2, x: -942 + 1920 / 4, y: -1080 + 1080 / 4)],
            sourceSpace: 2, targetSpace: 7))
    }

    func testTargetIsCurrentSpaceReturnsNil() {
        XCTAssertNil(SpaceTravelPlanner.plan(target: .index(2), windowSpace: 2, windowDisplay: 1,
                                             spaces: spaces, displays: displays))
    }

    func testNonexistentSpaceReturnsNil() {
        XCTAssertNil(SpaceTravelPlanner.plan(target: .index(42), windowSpace: 2, windowDisplay: 1,
                                             spaces: spaces, displays: displays))
    }

    func testSingleSpaceDisplayPrevNextReturnsNil() {
        let one: [SpaceInfo] = [.init(index: 1, display: 1, isVisible: true)]
        XCTAssertNil(SpaceTravelPlanner.plan(target: .next, windowSpace: 1, windowDisplay: 1,
                                             spaces: one, displays: displays))
    }

    func testSpaceTargetParse() {
        XCTAssertEqual(SpaceTarget.parse("prev"), .prev)
        XCTAssertEqual(SpaceTarget.parse("next"), .next)
        XCTAssertEqual(SpaceTarget.parse("3"), .index(3))
        XCTAssertNil(SpaceTarget.parse("0"))
        XCTAssertNil(SpaceTarget.parse("-1"))
        XCTAssertNil(SpaceTarget.parse("bogus"))
        XCTAssertNil(SpaceTarget.parse(""))
    }

    func testSpaceInfoDecodeList() {
        let json = """
        [{"index":1,"display":2,"is-visible":true,"label":""},
         {"index":2,"display":2,"is-visible":false}]
        """.data(using: .utf8)!
        XCTAssertEqual(SpaceInfo.decodeList(json),
                       [SpaceInfo(index: 1, display: 2, isVisible: true),
                        SpaceInfo(index: 2, display: 2, isVisible: false)])
        XCTAssertEqual(SpaceInfo.decodeList(Data()), [])
    }

    func testDisplayInfoDecodeList() {
        let json = """
        [{"index":1,"frame":{"x":0.0,"y":0.0,"w":1728.0,"h":1117.0}}]
        """.data(using: .utf8)!
        XCTAssertEqual(DisplayInfo.decodeList(json),
                       [DisplayInfo(index: 1, frame: YRect(x: 0, y: 0, w: 1728, h: 1117))])
        XCTAssertEqual(DisplayInfo.decodeList(Data()), [])
    }
}
