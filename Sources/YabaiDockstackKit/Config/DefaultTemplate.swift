import Foundation

public enum DefaultTemplate {
    public static func defaultYabaiSettings() -> YabaiSettings {
        let apps = ["Gifski", "LINE", "System Preferences", "System Settings", "System Information",
                    "Activity Monitor", "Hammerspoon", "Finder", "Calculator", "Alfred Preferences",
                    "Disk Utility", "Path Finder", "TeamViewer", "AppCleaner", "iStat Menus",
                    "Telegram", "Raycast"]
        var s = YabaiSettings.defaults
        s.rules = apps.map { WindowRule(app: $0, mode: .float) }
        return s
    }

    public static func defaultBindings() -> [ShortcutBinding] {
        ShortcutCatalog.all.map { ShortcutBinding(actionID: $0.id, enabled: true, hotkey: $0.defaultHotkey) }
    }

    @discardableResult
    public static func ensureManagedRegion(in writer: ConfigFileWriter, body: String) -> Bool {
        if ManagedRegion.extract(from: writer.currentText()) != nil { return false }
        try? writer.writeManagedRegion(body)
        return true
    }
}
