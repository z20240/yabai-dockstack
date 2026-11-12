import Foundation

/// Runtime rc-file detection: honours a running daemon's `-c` flag, else yabai/skhd's own lookup order.
public enum RcDetector {
    public static func detect(_ tool: RcTool) -> String {
        let flag = configFlag(for: tool, commandLines: runningCommandLines())
        let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
        return ConfigPaths.autoDetect(tool: tool, xdgConfigHome: xdg, home: NSHomeDirectory(),
                                      configFlag: flag,
                                      exists: { FileManager.default.fileExists(atPath: $0) })
    }

    /// The first `-c` / `--config` across ALL of the tool's processes (`ps` args lines),
    /// so a flag-less process listed first doesn't hide another's flag.
    public static func configFlag(for tool: RcTool, commandLines: [String]) -> String? {
        commandLines.lazy
            .filter { line in
                guard let argv0 = line.split(separator: " ", maxSplits: 1).first else { return false }
                return (String(argv0) as NSString).lastPathComponent == tool.rawValue
            }
            .compactMap { ConfigPaths.configFlag(inCommandLine: $0) }
            .first
    }

    private static func runningCommandLines() -> [String] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-axww", "-o", "args="]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0, let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
