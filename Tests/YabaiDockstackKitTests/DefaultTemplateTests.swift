import XCTest
@testable import YabaiDockstackKit

final class DefaultTemplateTests: XCTestCase {
    func testDefaultBindingsCoverCatalog() {
        let b = DefaultTemplate.defaultBindings()
        XCTAssertEqual(b.count, ShortcutCatalog.all.count)
        XCTAssertTrue(b.allSatisfy { $0.enabled })
        XCTAssertEqual(Set(b.map { $0.actionID }), Set(ShortcutCatalog.all.map { $0.id }))
    }

    func testDefaultYabaiSettingsAreSane() {
        let s = DefaultTemplate.defaultYabaiSettings()
        XCTAssertEqual(s.layout, .bsp)
        XCTAssertEqual(s.gap, 8)
        XCTAssertTrue(s.rules.contains(where: { $0.app == "Finder" && $0.mode == .float }))
    }

    func testEnsureSeedsThenAdopts() throws {
        let path = NSTemporaryDirectory() + "yst-tmpl-\(UUID().uuidString).rc"
        let w = ConfigFileWriter(path: path)
        let seeded = DefaultTemplate.ensureManagedRegion(in: w, body: "SEED")
        XCTAssertTrue(seeded)
        let adopted = DefaultTemplate.ensureManagedRegion(in: w, body: "IGNORED")
        XCTAssertFalse(adopted) // already has a region -> adopt, don't overwrite
        XCTAssertEqual(ManagedRegion.extract(from: w.currentText()), "SEED")
        try? FileManager.default.removeItem(atPath: path)
        try? FileManager.default.removeItem(atPath: w.backupPath)
    }
}
