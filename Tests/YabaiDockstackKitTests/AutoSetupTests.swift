import XCTest
@testable import YabaiDockstackKit

final class AutoSetupTests: XCTestCase {
    func testLocatorReturnsNilWhenNoCandidateExists() {
        XCTAssertNil(YabaiLocator.detect(candidates: ["/no/a", "/no/b"], exists: { _ in false }))
    }

    func testLocatorReturnsFirstExistingCandidate() {
        let p = YabaiLocator.detect(candidates: ["/no/a", "/yes/b", "/yes/c"],
                                    exists: { $0.hasPrefix("/yes") })
        XCTAssertEqual(p, "/yes/b")
    }

    func testSignalSpecsOnePerEvent() {
        let specs = SignalInstaller.specs(appBinaryPath: "/Apps/yst.app/Contents/MacOS/yst")
        XCTAssertEqual(specs.count, SignalInstaller.events.count)
    }

    func testSignalSpecLabelAndAction() {
        let specs = SignalInstaller.specs(appBinaryPath: "/Apps/yst.app/Contents/MacOS/yst")
        let first = specs[0]
        XCTAssertEqual(first.label, "yabai-dockstack-window_focused")
        XCTAssertEqual(first.action, "\"/Apps/yst.app/Contents/MacOS/yst\" --refresh")
    }
}
