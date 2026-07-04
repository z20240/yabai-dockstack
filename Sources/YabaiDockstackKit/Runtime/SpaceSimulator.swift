import AppKit
import CoreGraphics

/// Simulates the native "drag a window's titlebar and press ctrl+arrow" gesture
/// so windows can travel between spaces with SIP fully enabled. Requires the
/// Accessibility permission the app already holds.
public protocol SpaceSimulating {
    /// Returns true if every space transition was observed (or waited out).
    func dragWalk(grabX: Double, grabY: Double, direction: ArrowDirection, count: Int) -> Bool
}

public final class SpaceSimulator: SpaceSimulating {
    /// Per-step ceiling on waiting for the space-switch animation.
    private let stepTimeout: TimeInterval = 0.8
    /// Settle time after each observed switch (animation tail).
    private let settle: TimeInterval = 0.3

    public init() {}

    public func dragWalk(grabX: Double, grabY: Double, direction: ArrowDirection, count: Int) -> Bool {
        let point = CGPoint(x: grabX, y: grabY)
        let keyCode: CGKeyCode = direction == .left ? 123 : 124
        let source = CGEventSource(stateID: .hidSystemState)

        func post(_ e: CGEvent?) { e?.post(tap: .cghidEventTap); usleep(25_000) }

        // Park the cursor on the grab point before pressing — WindowServer
        // tracks the cursor, and a press far from it doesn't start a drag.
        post(CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                     mouseCursorPosition: point, mouseButton: .left))
        usleep(120_000)
        guard let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                                 mouseCursorPosition: point, mouseButton: .left) else { return false }
        down.post(tap: .cghidEventTap)
        defer {
            CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                    mouseCursorPosition: CGPoint(x: point.x + 10, y: point.y + 5),
                    mouseButton: .left)?.post(tap: .cghidEventTap)
        }
        // Real dragged events past the drag threshold actually lift the window;
        // a tiny jiggle reads as a click and the window stays behind.
        for i in 1...5 {
            post(CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged,
                         mouseCursorPosition: CGPoint(x: point.x + Double(i) * 2,
                                                      y: point.y + Double(i)),
                         mouseButton: .left))
        }
        usleep(150_000)

        var allObserved = true
        for _ in 0..<count {
            let waiter = SpaceChangeWaiter()
            postCtrlKey(keyCode)
            if !waiter.wait(timeout: stepTimeout) { allObserved = false }
            Thread.sleep(forTimeInterval: settle)
        }
        return allObserved
    }

    /// Posts ctrl+arrow the way the hardware does: a flagsChanged for the
    /// control press, the arrow key carrying the Fn/NumericPad bits physical
    /// arrow keys always have (the symbolic hotkey won't match without them),
    /// then the control release.
    private func postCtrlKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        if let e = CGEvent(keyboardEventSource: source, virtualKey: 59, keyDown: true) {
            e.type = .flagsChanged
            e.flags = .maskControl
            e.post(tap: .cghidEventTap)
        }
        usleep(30_000)
        for keyDown in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: keyCode,
                                  keyDown: keyDown) else { continue }
            e.flags = [.maskControl, .maskSecondaryFn, .maskNumericPad]
            e.post(tap: .cghidEventTap)
            usleep(30_000)
        }
        if let e = CGEvent(keyboardEventSource: source, virtualKey: 59, keyDown: false) {
            e.type = .flagsChanged
            e.flags = []
            e.post(tap: .cghidEventTap)
        }
    }
}

/// Blocks a background thread until macOS reports an active-space change.
/// The notification arrives on the main run loop, which stays free because
/// SpaceMover runs on its own serial queue.
final class SpaceChangeWaiter {
    private let semaphore = DispatchSemaphore(value: 0)
    private var token: NSObjectProtocol?

    init() {
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: nil) { [semaphore] _ in semaphore.signal() }
    }

    /// Returns true if the space change was observed within `timeout`.
    func wait(timeout: TimeInterval) -> Bool {
        let observed = semaphore.wait(timeout: .now() + timeout) == .success
        if let token { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        self.token = nil
        return observed
    }
}
