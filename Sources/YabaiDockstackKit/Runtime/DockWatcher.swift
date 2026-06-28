import AppKit
import ApplicationServices

public struct DockHover: Equatable {
    public let appTitle: String
    public let iconFrame: CGRect   // Cocoa screen coords (bottom-left origin)
}

/// Detects which Dock application icon the mouse is hovering, via a throttled
/// global mouse monitor + Accessibility hit-testing. Reports the app title and
/// the icon's screen frame; reports nil when the cursor leaves Dock items.
public final class DockWatcher {
    private let onHover: (DockHover?) -> Void
    private var monitor: Any?
    private var lastFire = Date.distantPast
    private var lastTitle: String?

    public init(onHover: @escaping (DockHover?) -> Void) { self.onHover = onHover }

    public func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.handleMove()
        }
    }

    public func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        lastTitle = nil
    }

    private func handleMove() {
        let now = Date()
        guard now.timeIntervalSince(lastFire) > 0.06 else { return }
        lastFire = now

        let mouse = NSEvent.mouseLocation                       // Cocoa global (bottom-left)
        let screenH = NSScreen.screens.first?.frame.height ?? 0
        let axPoint = CGPoint(x: mouse.x, y: screenH - mouse.y) // AX is top-left origin

        let system = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(axPoint.x), Float(axPoint.y), &element) == .success,
              let el = element else { reportNil(); return }

        var subroleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXSubroleAttribute as CFString, &subroleRef)
        guard (subroleRef as? String) == "AXApplicationDockItem" else { reportNil(); return }

        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &titleRef)
        let title = (titleRef as? String) ?? ""
        guard !title.isEmpty else { reportNil(); return }

        if title == lastTitle { return }   // same icon: don't re-fire
        lastTitle = title

        var posRef: CFTypeRef?; var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef)
        AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef)
        var pos = CGPoint.zero; var size = CGSize.zero
        if let p = posRef { AXValueGetValue(p as! AXValue, .cgPoint, &pos) }
        if let s = sizeRef { AXValueGetValue(s as! AXValue, .cgSize, &size) }
        let cocoa = CGRect(x: pos.x, y: screenH - pos.y - size.height,
                           width: size.width, height: size.height)

        onHover(DockHover(appTitle: title, iconFrame: cocoa))
    }

    private func reportNil() {
        if lastTitle != nil { lastTitle = nil; onHover(nil) }
    }
}
