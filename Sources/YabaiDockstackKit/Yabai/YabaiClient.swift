import Foundation

public final class YabaiClient {
    /// Mutable so the path can be changed at runtime (Settings). All holders share
    /// this instance, so an update applies everywhere immediately.
    public var path: String
    public init(yabaiPath: String) { self.path = yabaiPath }

    private func run(_ args: [String]) -> Data? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
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

    /// Map of space index → custom label (only spaces that have a non-empty label).
    public func querySpaceLabels() -> [Int: String] {
        guard let data = run(["-m", "query", "--spaces"]),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return [:]
        }
        var out: [Int: String] = [:]
        for s in arr {
            if let idx = s["index"] as? Int,
               let label = s["label"] as? String, !label.isEmpty {
                out[idx] = label
            }
        }
        return out
    }

    // MARK: - Space travel support (SIP-free SpaceMover)

    public func querySpacesInfo() -> [SpaceInfo] {
        guard let data = run(["-m", "query", "--spaces"]) else { return [] }
        return SpaceInfo.decodeList(data)
    }

    public func queryDisplaysInfo() -> [DisplayInfo] {
        guard let data = run(["-m", "query", "--displays"]) else { return [] }
        return DisplayInfo.decodeList(data)
    }

    /// The currently focused window, or nil if none / yabai unavailable.
    public func queryFocusedWindow() -> YabaiWindow? {
        guard let data = run(["-m", "query", "--windows", "--window"]),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let single = try? JSONSerialization.data(withJSONObject: [obj]) else { return nil }
        return YabaiWindow.decodeList(single).first
    }

    /// Absolute AX move — works without the scripting addition, including
    /// across displays (the window lands on the target display's visible space).
    public func moveWindow(id: Int, absX: Double, absY: Double) {
        _ = run(["-m", "window", String(id), "--move", "abs:\(Int(absX)):\(Int(absY))"])
    }

    public func balance(space: Int) {
        _ = run(["-m", "space", String(space), "--balance"])
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
        FileManager.default.isExecutableFile(atPath: path)
    }
}
