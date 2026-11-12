import Foundation

public struct ConfigFileWriter {
    public let path: String
    public var backupPath: String { path + ".bak" }
    private let fm = FileManager.default
    public init(path: String) { self.path = (path as NSString).expandingTildeInPath }

    /// The file's text for display; "" when it is missing or unreadable. Never use this
    /// as the base of a write — see `textForWriting()`.
    public func currentText() -> String {
        (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    }

    /// The file's text as the base of a write: "" when the file doesn't exist yet, but
    /// throws when it exists and can't be read as UTF-8 text — writing would otherwise
    /// replace the whole file with just dockstack's section.
    public func textForWriting() throws -> String {
        guard fm.fileExists(atPath: path) else { return "" }
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw NSError(domain: "ConfigFileWriter", code: 3, userInfo: [NSLocalizedDescriptionKey:
                "Refusing to write: \(path) exists but couldn't be read as UTF-8 text. Nothing was changed."])
        }
    }

    /// Back up the current file (if any) to `backupPath`, then write `text` verbatim.
    public func writeRaw(_ text: String) throws {
        if fm.fileExists(atPath: path) {
            if fm.fileExists(atPath: backupPath) { try? fm.removeItem(atPath: backupPath) }
            try fm.copyItem(atPath: path, toPath: backupPath)
        }
        let dir = (path as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try text.write(toFile: path, atomically: true, encoding: .utf8)
    }

    public func writeManagedRegion(_ body: String) throws {
        let existing = try textForWriting()
        if ManagedRegion.hasMalformedMarkers(in: existing) {
            throw NSError(domain: "ConfigFileWriter", code: 2, userInfo: [NSLocalizedDescriptionKey:
                "Refusing to write: \(path) has malformed yabai-dockstack managed markers (duplicate or unbalanced). Fix the markers by hand first."])
        }
        let updated = ManagedRegion.replace(in: existing, with: body)
        try writeRaw(updated)
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
