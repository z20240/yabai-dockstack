import Foundation

public enum RcTool: String { case yabai, skhd }

public enum ConfigPaths {
    public static var scriptsDir: String { ("~/.config/yabai-dockstack/scripts" as NSString).expandingTildeInPath }

    public static func resolve(candidates: [String], fileManager: FileManager = .default) -> String {
        let expanded = candidates.map { ($0 as NSString).expandingTildeInPath }
        return expanded.first { fileManager.fileExists(atPath: $0) } ?? expanded.first ?? ""
    }

    /// Where yabai/skhd themselves look for their rc, in priority order.
    public static func lookupOrder(tool: RcTool, xdgConfigHome: String?, home: String) -> [String] {
        let name = tool.rawValue
        let rc = name + "rc"
        var out: [String] = []
        if let xdg = xdgConfigHome, !xdg.isEmpty { out.append("\(xdg)/\(name)/\(rc)") }
        out.append("\(home)/.config/\(name)/\(rc)")
        out.append("\(home)/.\(rc)")
        return out
    }

    /// Value following `-c` / `--config` in a process command line (tilde-expanded), else nil.
    public static func configFlag(inCommandLine line: String) -> String? {
        let args = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let i = args.firstIndex(where: { $0 == "-c" || $0 == "--config" }),
              i + 1 < args.count else { return nil }
        return (args[i + 1] as NSString).expandingTildeInPath
    }

    /// `-c` flag wins; else first existing file in lookup order; else the first lookup entry.
    public static func autoDetect(tool: RcTool, xdgConfigHome: String?, home: String,
                                  configFlag: String?, exists: (String) -> Bool) -> String {
        if let flag = configFlag { return flag }
        let order = lookupOrder(tool: tool, xdgConfigHome: xdgConfigHome, home: home)
        return order.first(where: exists) ?? order[0]
    }
}
