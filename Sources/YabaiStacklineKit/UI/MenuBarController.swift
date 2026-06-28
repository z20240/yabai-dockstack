import AppKit

public final class MenuBarController {
    private let statusItem: NSStatusItem
    private let statusInfoItem: NSMenuItem

    public var onQuit: (() -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var onReregisterSignals: (() -> Void)?

    public init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let path = Bundle.main.url(forResource: "menubar", withExtension: "png"),
           let img = NSImage(contentsOf: path) {
            img.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = img
        } else {
            statusItem.button?.title = "▦"
        }

        let menu = NSMenu()

        statusInfoItem = NSMenuItem(title: "yabai: …", action: nil, keyEquivalent: "")
        statusInfoItem.isEnabled = false
        menu.addItem(statusInfoItem)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(settingsAction), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let reregister = NSMenuItem(title: "Re-register yabai signals",
                                    action: #selector(reregisterAction), keyEquivalent: "")
        reregister.target = self
        menu.addItem(reregister)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    public func setStatus(_ text: String) {
        statusInfoItem.title = text
    }

    @objc private func settingsAction() { onOpenSettings?() }
    @objc private func reregisterAction() { onReregisterSignals?() }
    @objc private func quitAction() { onQuit?() }
}
