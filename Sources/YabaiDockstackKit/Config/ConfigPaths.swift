import Foundation

public enum ConfigPaths {
    public static let yabaiCandidates = ["~/.yabairc", "~/.config/yabai/yabairc"]
    public static let skhdCandidates = ["~/.skhdrc", "~/.config/skhd/skhdrc"]
    public static var scriptsDir: String { ("~/.config/yabai-dockstack/scripts" as NSString).expandingTildeInPath }

    public static func resolve(candidates: [String], fileManager: FileManager = .default) -> String {
        let expanded = candidates.map { ($0 as NSString).expandingTildeInPath }
        return expanded.first { fileManager.fileExists(atPath: $0) } ?? expanded.first ?? ""
    }
}
