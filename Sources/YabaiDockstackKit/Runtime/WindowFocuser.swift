import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Focuses a window on click/commit. yabai can't focus a window it holds no
/// AX reference for — e.g. LINE re-showing the same window after closing to
/// its tray (yabai never re-binds the reused id). Fall back to reopening the
/// owning app (as clicking its Dock icon would), then AX-raise that exact
/// window when the app exposes it.
public final class WindowFocuser {
    private let client: YabaiClient
    private let reopen: (_ pid: Int, _ windowId: Int) -> Void

    public init(client: YabaiClient,
                reopen: @escaping (_ pid: Int, _ windowId: Int) -> Void = WindowFocuser.reopenApp) {
        self.client = client
        self.reopen = reopen
    }

    /// Synchronous (runs yabai); call off the main thread where latency matters.
    public func focus(windowId: Int) {
        if client.focus(windowId: windowId) { return }
        guard let pid = client.queryWindows().first(where: { $0.id == windowId })?.pid else { return }
        reopen(pid, windowId)
    }

    /// Sends the app a reopen + activate, like `open -b <bundle id>`, then
    /// raises the requested window once the app is frontmost.
    public static func reopenApp(pid: Int, windowId: Int) {
        DispatchQueue.main.async {
            guard let url = NSRunningApplication(processIdentifier: pid_t(pid))?.bundleURL else { return }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                // A space switch may still be animating; try now and once more.
                raise(pid: pid, windowId: windowId)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { raise(pid: pid, windowId: windowId) }
            }
        }
    }

    /// AX-raises the app's window with `windowId` if it is in the app's AX
    /// window list (current spaces only). No-op otherwise.
    static func raise(pid: Int, windowId: Int) {
        let app = AXUIElementCreateApplication(pid_t(pid))
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return }
        for w in windows {
            var wid: CGWindowID = 0
            guard _AXUIElementGetWindow(w, &wid) == .success, Int(wid) == windowId else { continue }
            AXUIElementSetAttributeValue(w, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(w, kAXRaiseAction as CFString)
            return
        }
    }
}
