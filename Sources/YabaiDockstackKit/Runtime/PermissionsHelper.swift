import ApplicationServices
import CoreGraphics
import AppKit

/// Thin wrappers around the TCC permission checks the Dock-preview feature needs.
public enum PermissionsHelper {
    public static func hasAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    public static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    public static func hasScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    public static func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
    }

    public static var allGranted: Bool { hasAccessibility() && hasScreenRecording() }

    /// Open System Settings directly to the relevant Privacy pane.
    public static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    public static func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private static func open(_ urlString: String) {
        if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
    }
}
