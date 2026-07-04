import Foundation

public final class SignalListener {
    private let socketPath: String
    private let onPoke: () -> Void
    private let onCommand: ((String) -> Void)?
    private var fd: Int32 = -1
    private var running = false

    public init(socketPath: String, onPoke: @escaping () -> Void,
                onCommand: ((String) -> Void)? = nil) {
        self.socketPath = socketPath
        self.onPoke = onPoke
        self.onCommand = onCommand
    }

    public func start() {
        unlink(socketPath)  // remove stale socket
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            NSLog("yabai-dockstack: signal listener failed to create socket \(socketPath)")
            return
        }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathCapacity = MemoryLayout.size(ofValue: addr.sun_path)
        _ = socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path.0) { dst in
                strncpy(dst, ptr, pathCapacity - 1)
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, len) }
        }
        guard bound == 0, listen(fd, 8) == 0 else {
            NSLog("yabai-dockstack: signal listener failed to bind/listen \(socketPath)")
            close(fd)
            fd = -1
            return
        }
        running = true
        Thread.detachNewThread { [weak self] in self?.acceptLoop() }
    }

    private func acceptLoop() {
        while running {
            let client = accept(fd, nil, nil)
            if client < 0 { continue }
            var buf = [UInt8](repeating: 0, count: 64)
            let n = read(client, &buf, buf.count)
            close(client)
            let text = n > 0
                ? String(decoding: buf[0..<n], as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            if text.hasPrefix("move-space"), let onCommand {
                // Runs on the accept thread; SpaceMover hops to its own queue.
                onCommand(text)
            } else {
                DispatchQueue.main.async { [weak self] in self?.onPoke() }
            }
        }
    }

    public func stop() {
        running = false
        if fd >= 0 { close(fd); fd = -1 }
        unlink(socketPath)
    }
}
