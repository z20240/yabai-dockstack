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

    /// False when yabai couldn't focus it — e.g. a window an app closed to its
    /// tray / menu bar: still listed, but without an AX reference.
    @discardableResult
    public func focus(windowId: Int) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["-m", "window", "--focus", String(windowId)]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return false }
        proc.waitUntilExit()
        return proc.terminationStatus == 0
    }

    /// Swap two windows' positions (AX-based; also reorders windows inside a
    /// stack, and works without the scripting addition).
    public func swap(windowId: Int, with other: Int) {
        _ = run(["-m", "window", String(windowId), "--swap", String(other)])
    }

    /// Send a window to a space (needs the scripting addition on modern macOS).
    /// Needs the scripting addition. `focus` also follows the window there.
    public func moveToSpace(windowId: Int, space: Int, focus: Bool = false) {
        var args = ["-m", "window", String(windowId), "--space", String(space)]
        if focus { args.append("--focus") }
        _ = run(args)
    }

    public func focus(spaceId: Int) {
        _ = run(["-m", "space", "--focus", String(spaceId)])
    }


    /// Close a window (AX-based; works without the scripting addition).
    public func close(windowId: Int) {
        _ = run(["-m", "window", String(windowId), "--close"])
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

    /// `yabai -m config <key>` as an integer (paddings, gaps).
    public func configInt(_ key: String) -> Int? {
        AutoPadding.parse(run(["-m", "config", key]).map { String(decoding: $0, as: UTF8.self) })
    }

    /// What yabai is running now: layout, paddings/gap and `rule --list`. nil when
    /// yabai isn't reachable (no layout answer). Runs 7 short `yabai -m` calls.
    public func readLiveState() -> YabaiLiveState? {
        guard let layout = run(["-m", "config", "layout"])
                .map({ String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }),
              !layout.isEmpty else { return nil }
        return YabaiLiveState(layout: layout,
                              top: configInt("top_padding"), bottom: configInt("bottom_padding"),
                              left: configInt("left_padding"), right: configInt("right_padding"),
                              gap: configInt("window_gap"),
                              rules: run(["-m", "rule", "--list"]).map(LiveRule.decodeList) ?? [])
    }

    public func setConfig(_ key: String, _ value: Int) {
        _ = run(["-m", "config", key, String(value)])
    }

    public func balance(space: Int) {
        _ = run(["-m", "space", String(space), "--balance"])
    }

    /// Works without the scripting addition; used to unmanage a tiled window
    /// so it can be repositioned across displays, then re-tile it after.
    public func toggleFloat(windowId: Int) {
        _ = run(["-m", "window", String(windowId), "--toggle", "float"])
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
