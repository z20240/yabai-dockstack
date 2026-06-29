import Foundation

public enum ConfigApplier {
    public static func run(_ launchPath: String, _ args: [String]) -> (ok: Bool, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        do {
            try p.run(); p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (p.terminationStatus == 0, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (false, "\(error)")
        }
    }
}
