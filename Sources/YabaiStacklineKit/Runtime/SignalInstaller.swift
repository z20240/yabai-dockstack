import Foundation

/// Registers/unregisters the yabai signals that poke the app, so the user never
/// has to edit ~/.yabairc. Idempotent: install removes our labels first, then adds.
public enum SignalInstaller {
    /// yabai events that should trigger a redraw.
    public static let events = [
        "window_focused",
        "window_moved",
        "window_resized",
        "window_created",
        "window_destroyed",
        "space_changed",
        "display_changed",
        "application_front_switched",
    ]

    public static func label(for event: String) -> String { "yabai-stackline-\(event)" }

    public struct Spec: Equatable {
        public let event: String
        public let label: String
        public let action: String
    }

    /// Pure, testable: the signal specs for a given app binary path.
    public static func specs(appBinaryPath: String) -> [Spec] {
        events.map { event in
            Spec(event: event,
                 label: label(for: event),
                 action: "\"\(appBinaryPath)\" --refresh")
        }
    }

    public static func install(client: YabaiClient, appBinaryPath: String) {
        for spec in specs(appBinaryPath: appBinaryPath) {
            client.removeSignal(label: spec.label)   // idempotent
            client.addSignal(event: spec.event, label: spec.label, action: spec.action)
        }
    }

    public static func uninstall(client: YabaiClient) {
        for event in events { client.removeSignal(label: label(for: event)) }
    }

    public static func isInstalled(client: YabaiClient) -> Bool {
        let installed = Set(client.listSignalLabels())
        return events.allSatisfy { installed.contains(label(for: $0)) }
    }
}
