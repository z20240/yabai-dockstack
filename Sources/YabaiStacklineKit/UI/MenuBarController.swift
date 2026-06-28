import AppKit

public final class MenuBarController {
    private let statusItem: NSStatusItem
    public var onQuit: (() -> Void)?
    public var onToggleStyle: (() -> Void)?
    public var onReload: (() -> Void)?

    public init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "▦"
        let menu = NSMenu()
        let toggle = NSMenuItem(title: "Toggle icon/flag", action: #selector(toggleAction), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let reload = NSMenuItem(title: "Reload config", action: #selector(reloadAction), keyEquivalent: "")
        reload.target = self
        menu.addItem(reload)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func toggleAction() { onToggleStyle?() }
    @objc private func reloadAction() { onReload?() }
    @objc private func quitAction() { onQuit?() }
}
