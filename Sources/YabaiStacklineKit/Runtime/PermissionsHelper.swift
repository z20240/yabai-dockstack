import ApplicationServices
import CoreGraphics

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
}
