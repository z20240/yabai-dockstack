import Foundation

public enum IndicatorStyle: String, Codable { case icon, flag }

public struct AppConfig: Codable, Equatable {
    public var yabaiPath: String
    public var socketPath: String
    public var style: IndicatorStyle
    public var cellSize: Double
    public var offset: Double
    public var focusedAlpha: Double
    public var unfocusedAlpha: Double
    public var debounceSeconds: Double
    public var pollSeconds: Double
    /// Which edge a near-full-width window's indicator defaults to: "left" or "right".
    public var fullWidthSide: String
    /// Extra inset from the screen edge when the indicator would otherwise clamp
    /// to the very edge (keeps it off a window's rounded corner).
    public var edgeInset: Double
    /// Flag-mode bar color as "#RRGGBB" (or "#RRGGBBAA").
    public var flagColor: String
    /// Draw a rounded backing pill behind the indicators so they read as a
    /// floating chip (helps when overlapping a full-width window).
    public var showBackground: Bool
    /// Backing pill color as "#RRGGBB" / "#RRGGBBAA".
    public var backgroundColor: String
    /// Place the indicator inside the gap between the window and the screen edge
    /// (e.g. yabai's external padding) so it doesn't cover the app. The indicator
    /// shrinks to fit the gap. Falls back to overlapping if the gap is too small.
    public var confineToGap: Bool
    /// Show a window-preview popover when hovering a Dock app icon
    /// (needs Accessibility + Screen Recording).
    public var dockPreview: Bool
    /// UI language: "auto" (follow system), "en", "zh-Hant", or "ja".
    public var language: String
    /// Master toggle for the AltTab-style window switcher.
    public var switcherEnabled: Bool
    /// Switcher look: "thumbnails", "icons", or "titles".
    public var switcherAppearance: String
    /// Hold-to-cycle hotkeys via a global event tap (needs Accessibility).
    public var switcherHoldToCycle: Bool
    /// Capture ⌘⇥ itself (replaces the system app switcher while running).
    public var switcherCaptureCmdTab: Bool
    /// Hold-mode hotkeys in skhd notation ("alt - tab"); "" disables a scope.
    public var switcherHotkeyAll: String
    public var switcherHotkeyApp: String
    public var switcherHotkeySpace: String

    public static let defaults = AppConfig(
        yabaiPath: "/opt/homebrew/bin/yabai",
        socketPath: "/tmp/yabai-dockstack.sock",
        style: .icon, cellSize: 32, offset: 4,
        focusedAlpha: 1.0, unfocusedAlpha: 0.4,
        debounceSeconds: 0.05, pollSeconds: 3.0,
        fullWidthSide: "left",
        edgeInset: 6,
        flagColor: "#4C8DFF",
        showBackground: true,
        backgroundColor: "#1E1E1ECC",
        confineToGap: true,
        dockPreview: true,
        language: "auto",
        switcherEnabled: true,
        switcherAppearance: "thumbnails",
        switcherHoldToCycle: true,
        switcherCaptureCmdTab: false,
        switcherHotkeyAll: "alt - tab",
        switcherHotkeyApp: "alt - 0x32",
        switcherHotkeySpace: "")

    public static func load(from data: Data?) -> AppConfig {
        guard let data,
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return defaults
        }
        // Merge raw over defaults at the JSON-object level, then decode.
        var merged = (try? JSONSerialization.jsonObject(
            with: JSONEncoder().encode(defaults))) as? [String: Any] ?? [:]
        for (k, v) in raw { merged[k] = v }
        guard let mergedData = try? JSONSerialization.data(withJSONObject: merged),
              let cfg = try? JSONDecoder().decode(AppConfig.self, from: mergedData) else {
            return defaults
        }
        return cfg
    }

    /// Loads from a file path, expanding `~`. Missing file → defaults.
    public static func loadFromFile(_ path: String) -> AppConfig {
        let expanded = (path as NSString).expandingTildeInPath
        return load(from: try? Data(contentsOf: URL(fileURLWithPath: expanded)))
    }

    public func save(to path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        let dir = (expanded as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: URL(fileURLWithPath: expanded))
        }
    }
}
