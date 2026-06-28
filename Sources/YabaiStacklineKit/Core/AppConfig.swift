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

    public static let defaults = AppConfig(
        yabaiPath: "/opt/homebrew/bin/yabai",
        socketPath: "/tmp/yabai-stackline.sock",
        style: .icon, cellSize: 32, offset: 4,
        focusedAlpha: 1.0, unfocusedAlpha: 0.4,
        debounceSeconds: 0.3, pollSeconds: 3.0)

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
