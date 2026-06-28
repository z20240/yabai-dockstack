import Foundation

public enum RefreshClient {
    public static func sendPoke(socketPath: String) {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        defer { close(fd) }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathCapacity = MemoryLayout.size(ofValue: addr.sun_path)
        _ = socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path.0) { dst in
                strncpy(dst, ptr, pathCapacity - 1)
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, len) }
        }
        guard ok == 0 else { return }
        var byte: UInt8 = 1
        _ = write(fd, &byte, 1)
    }
}
