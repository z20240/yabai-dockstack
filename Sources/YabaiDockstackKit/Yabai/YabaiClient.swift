import Foundation

public struct YabaiClient {
    private let yabaiPath: String
    public init(yabaiPath: String) { self.yabaiPath = yabaiPath }

    private func run(_ args: [String]) -> Data? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: yabaiPath)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return data
    }

    public func queryWindows() -> [YabaiWindow] {
        guard let data = run(["-m", "query", "--windows"]) else { return [] }
        return YabaiWindow.decodeList(data)
    }

    public func focus(windowId: Int) {
        _ = run(["-m", "window", "--focus", String(windowId)])
    }

    // MARK: - Signal management

    public func addSignal(event: String, label: String, action: String) {
        _ = run(["-m", "signal", "--add", "event=\(event)", "action=\(action)", "label=\(label)"])
    }

    public func removeSignal(label: String) {
        _ = run(["-m", "signal", "--remove", label])
    }

    public func listSignalLabels() -> [String] {
        guard let data = run(["-m", "signal", "--list"]),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return arr.compactMap { $0["label"] as? String }
    }

    /// Returns true if the yabai binary is present and executable.
    public func isAvailable() -> Bool {
        FileManager.default.isExecutableFile(atPath: yabaiPath)
    }

    public var path: String { yabaiPath }
}
