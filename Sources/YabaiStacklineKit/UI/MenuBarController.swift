import AppKit

public final class MenuBarController {
    private let statusItem: NSStatusItem
    private let statusInfoItem: NSMenuItem
    private let loginItem: NSMenuItem

    public var onQuit: (() -> Void)?
    public var onToggleStyle: (() -> Void)?
    public var onReload: (() -> Void)?
    public var onReregisterSignals: (() -> Void)?
    public var onToggleLoginItem: (() -> Void)?

    public init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "▦"

        // All stored properties must be initialized before `self` is used.
        statusInfoItem = NSMenuItem(title: "yabai: …", action: nil, keyEquivalent: "")
        statusInfoItem.isEnabled = false
        loginItem = NSMenuItem(title: "Start at login",
                               action: #selector(loginAction), keyEquivalent: "")

        let menu = NSMenu()
        menu.addItem(statusInfoItem)

        let reregister = NSMenuItem(title: "Re-register yabai signals",
                                    action: #selector(reregisterAction), keyEquivalent: "")
        reregister.target = self
        menu.addItem(reregister)

        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Toggle icon/flag",
                                action: #selector(toggleAction), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let reload = NSMenuItem(title: "Reload config",
                                action: #selector(reloadAction), keyEquivalent: "")
        reload.target = self
        menu.addItem(reload)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    /// Update the connection status line, e.g. "yabai: connected ✓".
    public func setStatus(_ text: String) {
        statusInfoItem.title = text
    }

    public func setLoginItemChecked(_ checked: Bool) {
        loginItem.state = checked ? .on : .off
    }

    @objc private func toggleAction() { onToggleStyle?() }
    @objc private func reloadAction() { onReload?() }
    @objc private func reregisterAction() { onReregisterSignals?() }
    @objc private func loginAction() { onToggleLoginItem?() }
    @objc private func quitAction() { onQuit?() }
}
