import Foundation

public enum ScriptInstaller {
    public static let scriptNames = [
        "focusWindow.sh", "moveWindowToLeft.sh", "moveWindowToRight.sh",
        "moveWindowOnDisplaySpace.sh", "moveWindowToSpace.sh",
        "openWindowMenu.sh",
        "taggleShowHideDesktop.sh", "windowFocusOnDestroy.sh",
    ]

    public static func install(to dir: String, bundle: Bundle? = nil) throws {
        let bundle = bundle ?? .module
        let fm = FileManager.default
        let expanded = (dir as NSString).expandingTildeInPath
        try fm.createDirectory(atPath: expanded, withIntermediateDirectories: true)
        for name in scriptNames {
            guard let src = bundle.url(forResource: "scripts/\(name)", withExtension: nil)
                    ?? bundle.url(forResource: name, withExtension: nil, subdirectory: "scripts") else {
                throw NSError(domain: "ScriptInstaller", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Bundled script not found: \(name)"])
            }
            let dst = expanded + "/" + name
            if fm.fileExists(atPath: dst) { try fm.removeItem(atPath: dst) }
            try fm.copyItem(at: src, to: URL(fileURLWithPath: dst))
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst)
        }
    }

    /// True when any bundled script is missing on disk or its installed
    /// content differs from the bundled copy (i.e. an app update shipped
    /// new script logic and we should overwrite).
    public static func needsUpdate(dir: String, bundle: Bundle? = nil) -> Bool {
        let bundle = bundle ?? .module
        let expanded = (dir as NSString).expandingTildeInPath
        for name in scriptNames {
            guard let src = bundle.url(forResource: "scripts/\(name)", withExtension: nil)
                    ?? bundle.url(forResource: name, withExtension: nil, subdirectory: "scripts"),
                  let bundled = try? Data(contentsOf: src) else { return true }
            guard let installed = FileManager.default.contents(atPath: expanded + "/" + name),
                  installed == bundled else { return true }
        }
        return false
    }
}
