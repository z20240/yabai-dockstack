import Foundation
import ServiceManagement

/// Wraps SMAppService so "Start at login" is a one-click toggle (macOS 13+),
/// with no manual LaunchAgent plist.
public enum LoginItem {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns true on success.
    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}
