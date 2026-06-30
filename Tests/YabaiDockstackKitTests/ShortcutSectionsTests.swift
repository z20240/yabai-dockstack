import XCTest
@testable import YabaiDockstackKit

final class ShortcutSectionsTests: XCTestCase {
    func testSectionsFollowGroupOrderAndCoverCatalog() {
        let sections = ShortcutSections.build(DefaultTemplate.defaultBindings())
        XCTAssertEqual(sections.map { $0.group }, ShortcutGroup.order)
        let totalRows = sections.reduce(0) { $0 + $1.rows.count }
        XCTAssertEqual(totalRows, ShortcutCatalog.all.count)
        // rows within a section are in catalog order
        if let general = sections.first(where: { $0.group == "General" }) {
            let ids = general.rows.map { $0.action.id }
            let catalogIDs = ShortcutCatalog.all.filter { $0.group == "General" }.map { $0.id }
            XCTAssertEqual(ids, catalogIDs)
        }
    }

    func testMissingBindingBecomesDisabledRow() {
        let sections = ShortcutSections.build([]) // no bindings at all
        let rows = sections.flatMap { $0.rows }
        XCTAssertEqual(rows.count, ShortcutCatalog.all.count)
        XCTAssertTrue(rows.allSatisfy { !$0.binding.enabled && $0.binding.hotkey == nil })
    }

    func testConflictingActionIDs() {
        let hk = Hotkey(mods: [.alt, .cmd], key: "x")
        let bindings = [
            ShortcutBinding(actionID: "balance", enabled: true, hotkey: hk),
            ShortcutBinding(actionID: "toggle-fullscreen", enabled: true, hotkey: hk),
            ShortcutBinding(actionID: "rotate-cw", enabled: true, hotkey: Hotkey(mods: [.alt], key: "y")),
        ]
        XCTAssertEqual(ShortcutSections.conflictingActionIDs(bindings), Set(["balance", "toggle-fullscreen"]))
    }
}
