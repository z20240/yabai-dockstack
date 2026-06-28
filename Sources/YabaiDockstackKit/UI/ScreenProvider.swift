import AppKit

public struct ScreenInfo {
    public let yabaiFrame: YRect
    public let cocoaFrame: CGRect
}

public enum ScreenProvider {
    public static func primaryHeight() -> Double {
        Double(NSScreen.screens.first?.frame.height ?? 0)
    }

    public static func screens() -> [ScreenInfo] {
        let primaryH = primaryHeight()
        return NSScreen.screens.map { s in
            let f = s.frame
            // convert Cocoa (bottom-left) back to yabai (top-left)
            let yTop = primaryH - Double(f.origin.y) - Double(f.height)
            return ScreenInfo(
                yabaiFrame: YRect(x: Double(f.origin.x), y: yTop,
                                  w: Double(f.width), h: Double(f.height)),
                cocoaFrame: f)
        }
    }
}
