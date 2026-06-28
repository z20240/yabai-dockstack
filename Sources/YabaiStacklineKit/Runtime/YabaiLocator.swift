import Foundation

/// Locates the yabai binary so users don't have to configure a path.
public enum YabaiLocator {
    public static let defaultCandidates = [
        "/opt/homebrew/bin/yabai",      // Apple Silicon Homebrew
        "/usr/local/bin/yabai",         // Intel Homebrew
        "/run/current-system/sw/bin/yabai",  // nix-darwin
    ]

    /// Pure, testable: returns the first candidate that `exists` accepts.
    public static func detect(candidates: [String], exists: (String) -> Bool) -> String? {
        candidates.first(where: exists)
    }

    /// Detects yabai on the real filesystem: known candidates first, then `which`.
    public static func detect() -> String? {
        let fm = FileManager.default
        if let p = detect(candidates: defaultCandidates, exists: { fm.isExecutableFile(atPath: $0) }) {
            return p
        }
        return whichYabai()
    }

    private static func whichYabai() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = ["yabai"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : path
    }

    /// Resolves the effective yabai path: a valid configured path wins, else autodetect.
    public static func resolve(configuredPath: String) -> String? {
        if FileManager.default.isExecutableFile(atPath: configuredPath) {
            return configuredPath
        }
        return detect()
    }
}
