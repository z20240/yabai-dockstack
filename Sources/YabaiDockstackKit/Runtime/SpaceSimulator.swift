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
    private let settle: TimeInterval = 0.2

    public init() {}

    public func dragWalk(grabX: Double, grabY: Double, direction: ArrowDirection, count: Int) -> Bool {
        let point = CGPoint(x: grabX, y: grabY)
        let keyCode: CGKeyCode = direction == .left ? 123 : 124
        guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                 mouseCursorPosition: point, mouseButton: .left) else { return false }
        down.post(tap: .cghidEventTap)
        // A small drag makes the WindowServer attach the window to the pointer.
        if let jiggle = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged,
                                mouseCursorPosition: CGPoint(x: point.x + 3, y: point.y + 2),
                                mouseButton: .left) {
            jiggle.post(tap: .cghidEventTap)
        }
        defer {
            CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                    mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        }
        Thread.sleep(forTimeInterval: 0.1)  // let the drag register

        var allObserved = true
        for _ in 0..<count {
            let waiter = SpaceChangeWaiter()
            postCtrlKey(keyCode)
            if !waiter.wait(timeout: stepTimeout) { allObserved = false }
            Thread.sleep(forTimeInterval: settle)
        }
        return allObserved
    }

    private func postCtrlKey(_ keyCode: CGKeyCode) {
        for keyDown in [true, false] {
            guard let e = CGEvent(keyboardEventSource: nil, virtualKey: keyCode,
                                  keyDown: keyDown) else { continue }
            e.flags = .maskControl
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
