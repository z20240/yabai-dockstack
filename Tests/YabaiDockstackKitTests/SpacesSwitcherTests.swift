import XCTest
import CoreGraphics
@testable import YabaiDockstackKit

final class SpacesSwitcherTests: XCTestCase {
    private func win(_ id: Int, space: Int, display: Int = 1, stack: Int = 0) -> YabaiWindow {
        YabaiWindow(id: id, pid: id, app: "A", title: "t\(id)", frame: YRect(x: 0, y: 0, w: 200, h: 100),
                    display: display, space: space, stackIndex: stack, hasFocus: false)
    }
    private func item(_ w: YabaiWindow) -> SwitcherItem {
        SwitcherItem(id: w.id, pid: w.pid, app: w.app, title: w.title, space: w.space,
                     display: w.display, hasFocus: false)
    }

    func testBuildCardsWithTilesMatchesAndFlags() {
        let spaces = [SpaceInfo(index: 1, display: 1, isVisible: true, hasFocus: true),
                      SpaceInfo(index: 2, display: 1, isVisible: false),
                      SpaceInfo(index: 3, display: 2, isVisible: true, isNativeFullscreen: true)]
        let windows = [win(11, space: 1, stack: 1), win(12, space: 1, stack: 0), win(31, space: 3, display: 2)]
        let cards = SpacesSwitcherModel.build(items: windows.map(item), windows: windows, spaces: spaces,
                                              labels: [2: "web"], matching: [11, 31])
        XCTAssertEqual(cards.map(\.space), [1, 2, 3])
        XCTAssertEqual(cards.map(\.name), ["Space 1", "web", "Space 3"])
        XCTAssertEqual(cards[0].tiles.map(\.item.id), [12, 11])
        XCTAssertEqual(cards[0].tiles.map(\.matches), [false, true])
        XCTAssertEqual(cards[0].tiles.first?.aspect, 2)
        XCTAssertTrue(cards[2].isFullscreen)
        XCTAssertTrue(cards[0].hasFocus)
        XCTAssertTrue(cards[1].tiles.isEmpty)
        XCTAssertEqual(SpacesSwitcherModel.selectable(cards).map(\.id), [11, 31])
    }

    func testSpacesFromWindowsStandsInBeforeTheSpacesQuery() {
        let focused = YabaiWindow(id: 21, pid: 21, app: "A", title: "t21", frame: YRect(x: 0, y: 0, w: 200, h: 100),
                                  display: 2, space: 4, stackIndex: 0, hasFocus: true)
        let hidden = YabaiWindow(id: 31, pid: 31, app: "A", title: "t31", frame: YRect(x: 0, y: 0, w: 200, h: 100),
                                 display: 1, space: 3, stackIndex: 0, hasFocus: false, isVisible: false)
        let windows = [win(11, space: 1), win(12, space: 1), focused, hidden, win(99, space: 0)]
        let spaces = SpacesSwitcherModel.spacesFromWindows(windows)
        XCTAssertEqual(spaces, [SpaceInfo(index: 1, display: 1, isVisible: true),
                                SpaceInfo(index: 3, display: 1, isVisible: false),
                                SpaceInfo(index: 4, display: 2, isVisible: true, hasFocus: true)])
        let cards = SpacesSwitcherModel.build(items: windows.map(item), windows: windows, spaces: spaces,
                                              labels: [:], matching: [11, 21])
        XCTAssertEqual(SpacesSwitcherModel.selectable(cards).map(\.id), [11, 21],
                       "every selectable item is a visible tile, even before the spaces query")
        XCTAssertTrue(SpacesSwitcherModel.spacesFromWindows([]).isEmpty)
    }

    func testSpaceInfoDecodesFocus() {
        let json = #"[{"index":1,"display":1,"is-visible":true,"has-focus":true},{"index":2,"display":1}]"#
        XCTAssertEqual(SpaceInfo.decodeList(Data(json.utf8)).map(\.hasFocus), [true, false])
    }

    func testSpatialNav() {
        let rects = [CGRect(x: 0, y: 0, width: 100, height: 50), CGRect(x: 120, y: 0, width: 100, height: 50),
                     CGRect(x: 10, y: 80, width: 100, height: 50)]
        XCTAssertEqual(SpatialNav.neighbor(of: 1, up: false, rects: rects), 2)
        XCTAssertEqual(SpatialNav.neighbor(of: 2, up: true, rects: rects), 0)
        XCTAssertNil(SpatialNav.neighbor(of: 0, up: true, rects: rects))
        XCTAssertNil(SpatialNav.neighbor(of: 9, up: true, rects: rects))
    }

    func testDropTargetSkipsFullscreenGapsAndHidden() {
        let cards = [(space: 1, rect: CGRect(x: 0, y: 0, width: 100, height: 100), isFullscreen: false),
                     (space: 3, rect: CGRect(x: 120, y: 0, width: 100, height: 100), isFullscreen: true)]
        XCTAssertEqual(SpacesInteraction.dropTarget(at: CGPoint(x: 50, y: 50), cards: cards, visible: nil), 1)
        XCTAssertNil(SpacesInteraction.dropTarget(at: CGPoint(x: 150, y: 50), cards: cards, visible: nil))
        XCTAssertNil(SpacesInteraction.dropTarget(at: CGPoint(x: 110, y: 50), cards: cards, visible: nil))
        XCTAssertNil(SpacesInteraction.dropTarget(at: CGPoint(x: 50, y: 50), cards: cards,
                                                  visible: CGRect(x: 0, y: 60, width: 300, height: 100)))
    }

    func testSwapAllowed() {
        XCTAssertTrue(SpacesInteraction.swapAllowed(source: 1, target: 2, saAvailable: true, fullscreen: []))
        XCTAssertFalse(SpacesInteraction.swapAllowed(source: 1, target: 1, saAvailable: true, fullscreen: []))
        XCTAssertFalse(SpacesInteraction.swapAllowed(source: 1, target: 2, saAvailable: false, fullscreen: []))
        XCTAssertFalse(SpacesInteraction.swapAllowed(source: 1, target: 3, saAvailable: true, fullscreen: [3]))
    }

    func testCardClick() {
        XCTAssertEqual(SpacesInteraction.cardClick(space: 4, saAvailable: true, recentWindowInSpace: nil), .focusSpace(4))
        XCTAssertEqual(SpacesInteraction.cardClick(space: 4, saAvailable: false, recentWindowInSpace: 9), .focusWindow(9))
        XCTAssertEqual(SpacesInteraction.cardClick(space: 4, saAvailable: false, recentWindowInSpace: nil), .nothing)
    }

    func testRecentWindowFallsBackToFirstTile() {
        XCTAssertEqual(SpacesInteraction.recentWindow(inSpace: 2, mru: [9, 21], tilesInSpace: [22, 21]), 21)
        XCTAssertEqual(SpacesInteraction.recentWindow(inSpace: 2, mru: [9], tilesInSpace: [22, 21]), 22)
        XCTAssertNil(SpacesInteraction.recentWindow(inSpace: 2, mru: [9], tilesInSpace: []))
    }

    func testWindowMoveRules() {
        XCTAssertTrue(SpacesInteraction.moveAllowed(from: 1, to: 2, fullscreen: []))
        XCTAssertFalse(SpacesInteraction.moveAllowed(from: 1, to: 1, fullscreen: []))
        XCTAssertFalse(SpacesInteraction.moveAllowed(from: 3, to: 2, fullscreen: [3]))
        XCTAssertFalse(SpacesInteraction.moveAllowed(from: 1, to: 3, fullscreen: [3]))
    }

    func testPillOnlyOnTilesThatFitIt() {
        XCTAssertTrue(SpacesInteraction.pillFits(CGSize(width: 80, height: 50)))
        XCTAssertFalse(SpacesInteraction.pillFits(CGSize(width: 34, height: 19)))
        XCTAssertFalse(SpacesInteraction.pillFits(CGSize(width: 24, height: 40)))
    }

    func testHoverGateWaitsForRealPointerMovement() {
        XCTAssertTrue(SpacesInteraction.hoverPasses(gate: nil, pointer: CGPoint(x: 5, y: 5)))
        XCTAssertFalse(SpacesInteraction.hoverPasses(gate: CGPoint(x: 100, y: 100), pointer: CGPoint(x: 103, y: 98)))
        XCTAssertTrue(SpacesInteraction.hoverPasses(gate: CGPoint(x: 100, y: 100), pointer: CGPoint(x: 106, y: 100)))
    }

    func testActionsNeedAVisibleHighlight() {
        XCTAssertEqual(SpacesInteraction.actionIndex(selection: 2, count: 5, highlighted: true), 2)
        XCTAssertNil(SpacesInteraction.actionIndex(selection: 2, count: 5, highlighted: false))
        XCTAssertNil(SpacesInteraction.actionIndex(selection: 0, count: 0, highlighted: true))
    }
}
