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
}
