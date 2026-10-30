import AppKit
import XCTest
@testable import YabaiDockstackKit

final class SwitcherControllerTests: XCTestCase {
    @MainActor
    func testFirstSearchOpenUsesOnlySpacesPanelBeforeAndAfterLoading() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("switcher-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("yabai")
        try """
        #!/bin/sh
        case "$*" in
          *--spaces*) echo '[{"index":1,"display":1,"is-visible":true,"has-focus":true}]' ;;
          *) echo '[]' ;;
        esac
        """.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let holdPanel = SwitcherPanel()
        let searchPanel = SpacesPanel()
        let controller = SwitcherController(client: YabaiClient(yabaiPath: executable.path),
                                            cache: ThumbnailCache(), config: .defaults,
                                            panel: holdPanel, spacesPanel: searchPanel)
        defer { controller.cancel() }
        let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))

        XCTAssertTrue(controller.open(scope: .allWindows, sticky: true))
        XCTAssertTrue(searchPanel.isVisible, "The search panel must open even before spaces are cached")
        XCTAssertFalse(holdPanel.isVisible, "Cold search must never fall back to the Alt-Tab panel")
        let window = try XCTUnwrap(NSApp.windows.first {
            !existingWindows.contains(ObjectIdentifier($0)) && $0.isVisible
        })
        let initialHeight = window.frame.height

        // A populated space card makes the initial search-only panel taller.
        // Wait for that actual render, rather than assuming a query duration.
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            window.frame.height > initialHeight
        }, object: nil)
        await fulfillment(of: [loaded], timeout: 5)
        XCTAssertTrue(searchPanel.isVisible)
        XCTAssertFalse(holdPanel.isVisible)

        controller.cancel()
        XCTAssertFalse(controller.isOpen)
        XCTAssertTrue(controller.open(scope: .allWindows, sticky: true))
        XCTAssertTrue(searchPanel.isVisible, "Warm opens must use the same panel as cold opens")
        XCTAssertFalse(holdPanel.isVisible)
    }
}
