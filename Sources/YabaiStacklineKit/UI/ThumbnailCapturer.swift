import ScreenCaptureKit
import CoreGraphics

/// Captures window thumbnails via ScreenCaptureKit. Per the spike finding, capture
/// only works for windows that are currently on-screen (`SCWindow.isOnScreen`);
/// windows on hidden spaces cannot be captured and return nil.
public final class ThumbnailCapturer {
    public init() {}

    private func capture(_ win: SCWindow, maxWidth: CGFloat) async -> CGImage? {
        guard win.isOnScreen, win.frame.width > 1, win.frame.height > 1 else { return nil }
        let filter = SCContentFilter(desktopIndependentWindow: win)
        let cfg = SCStreamConfiguration()
        let scale = min(1.0, maxWidth / win.frame.width)
        cfg.width = max(2, Int(win.frame.width * scale))
        cfg.height = max(2, Int(win.frame.height * scale))
        cfg.showsCursor = false
        return try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
    }

    /// Capture one window by CGWindowID, or nil if it isn't on-screen / on error.
    public func capture(windowID: Int, maxWidth: CGFloat = 480) async -> CGImage? {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: false),
            let win = content.windows.first(where: { Int($0.windowID) == windowID }) else { return nil }
        return await capture(win, maxWidth: maxWidth)
    }

    /// Capture all currently on-screen windows among `windowIDs` (for cache warming).
    public func captureOnScreen(windowIDs: Set<Int>, maxWidth: CGFloat = 480) async -> [Int: CGImage] {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true) else { return [:] }
        var out: [Int: CGImage] = [:]
        for win in content.windows where windowIDs.contains(Int(win.windowID)) {
            if let img = await capture(win, maxWidth: maxWidth) {
                out[Int(win.windowID)] = img
            }
        }
        return out
    }
}
