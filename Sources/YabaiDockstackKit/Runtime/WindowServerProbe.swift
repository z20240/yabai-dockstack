import Foundation

/// WindowServer facts yabai doesn't expose reliably. SkyLight is private, so
/// its symbols are resolved at runtime instead of linked.
public enum WindowServerProbe {
    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias WindowIsOrderedIn = @convention(c) (Int32, UInt32, UnsafeMutablePointer<UInt8>) -> Int32

    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static let mainConnectionID: MainConnectionID? = symbol("SLSMainConnectionID")
    private static let windowIsOrderedIn: WindowIsOrderedIn? = symbol("SLSWindowIsOrderedIn")

    private static func symbol<T>(_ name: String) -> T? {
        guard let skyLight, let sym = dlsym(skyLight, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    /// True when the window is ordered in — shown, on this or another space.
    /// False for windows an app closed to its tray (ordered out), for ids
    /// WindowServer no longer knows, and when SkyLight is unavailable.
    public static func isOrderedIn(_ windowId: Int) -> Bool {
        guard windowId > 0, windowId <= Int(UInt32.max),
              let mainConnectionID, let windowIsOrderedIn else { return false }
        var flag: UInt8 = 0
        return windowIsOrderedIn(mainConnectionID(), UInt32(windowId), &flag) == 0 && flag != 0
    }
}
