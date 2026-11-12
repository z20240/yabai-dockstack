import Foundation

/// Runtime rc-file detection: honours a running daemon's `-c` flag, else yabai/skhd's own lookup order.
public enum RcDetector {
    public static func detect(_ tool: RcTool) -> String {
        let flag = runningCommandLines()
            .first { line in
                guard let argv0 = line.split(separator: " ", maxSplits: 1).first else { return false }
                return (String(argv0) as NSString).lastPathComponent == tool.rawValue
            }
            .flatMap { ConfigPaths.configFlag(inCommandLine: $0) }
        let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
        return ConfigPaths.autoDetect(tool: tool, xdgConfigHome: xdg, home: NSHomeDirectory(),
                                      configFlag: flag,
                                      exists: { FileManager.default.fileExists(atPath: $0) })
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
