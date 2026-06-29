import XCTest
@testable import YabaiDockstackKit

final class ShortcutCatalogTests: XCTestCase {
    func testCatalogHasUniqueIDs() {
        let ids = ShortcutCatalog.all.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate action id")
    }

    func testCatalogGroupsAreKnown() {
        for a in ShortcutCatalog.all {
            XCTAssertTrue(ShortcutGroup.order.contains(a.group), "unknown group \(a.group)")
        }
    }

    func testCoreActionsPresent() {
        for id in ["restart-services", "toggle-show-desktop", "close-window",
                   "focus-left", "stack-west", "send-space-1", "grid-top-left"] {
            XCTAssertNotNil(ShortcutCatalog.action(id: id), "missing \(id)")
        }
    }

    func testConflictDetection() {
        let hk = Hotkey(mods: [.cmd], key: "x")
        let bindings = [
            ShortcutBinding(actionID: "a", enabled: true, hotkey: hk),
            ShortcutBinding(actionID: "b", enabled: true, hotkey: hk),
            ShortcutBinding(actionID: "c", enabled: true, hotkey: Hotkey(mods: [.cmd], key: "y")),
            ShortcutBinding(actionID: "d", enabled: false, hotkey: hk), // disabled -> ignored
        ]
        let conflicts = ShortcutConflicts.find(bindings)
        XCTAssertEqual(conflicts[hk].map { Set($0) }, Set(["a", "b"]))
        XCTAssertNil(conflicts[Hotkey(mods: [.cmd], key: "y")])
    }
}
