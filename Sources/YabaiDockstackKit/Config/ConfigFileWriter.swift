import Foundation

public struct ConfigFileWriter {
    public let path: String
    public var backupPath: String { path + ".bak" }
    private let fm = FileManager.default
    public init(path: String) { self.path = (path as NSString).expandingTildeInPath }

    public func currentText() -> String {
        (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    }

    public func writeManagedRegion(_ body: String) throws {
        if fm.fileExists(atPath: path) {
            if fm.fileExists(atPath: backupPath) { try? fm.removeItem(atPath: backupPath) }
            try fm.copyItem(atPath: path, toPath: backupPath)
        }
        let dir = (path as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let updated = ManagedRegion.replace(in: currentText(), with: body)
        try updated.write(toFile: path, atomically: true, encoding: .utf8)
    }

    public func restoreBackup() throws {
        guard fm.fileExists(atPath: backupPath) else {
            throw NSError(domain: "ConfigFileWriter", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No backup at \(backupPath)"])
        }
        if fm.fileExists(atPath: path) { try fm.removeItem(atPath: path) }
        try fm.copyItem(atPath: backupPath, toPath: path)
    }
}
