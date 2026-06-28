import AppKit

public final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    public var onQuit: (() -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var onReregisterSignals: (() -> Void)?
    public var onSelectWindow: ((Int) -> Void)?
    public var statusProvider: (() -> String)?
    public var windowListProvider: (() -> [WindowMenuModel.DisplayGroup])?

    public override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let path = Bundle.main.url(forResource: "menubar", withExtension: "png"),
           let img = NSImage(contentsOf: path) {
            img.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = img
        } else {
            statusItem.button?.title = "▦"
        }
        menu.delegate = self
        statusItem.menu = menu
        rebuild()
    }

    // Rebuild dynamic contents whenever the menu is about to open.
    public func menuNeedsUpdate(_ menu: NSMenu) { rebuild() }

    private func appIcon(pid: Int) -> NSImage {
        let img = NSRunningApplication(processIdentifier: pid_t(pid))?.icon
            ?? NSWorkspace.shared.icon(for: .applicationBundle)
        img.size = NSSize(width: 16, height: 16)
        return img
    }

    private func truncate(_ s: String, _ max: Int = 60) -> String {
        s.count <= max ? s : String(s.prefix(max - 1)) + "…"
    }

    private func disabledHeader(_ title: String, indent: Int) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.indentationLevel = indent
        return item
    }

    private func rebuild() {
        menu.removeAllItems()

        let status = NSMenuItem(title: statusProvider?() ?? "yabai: …", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let groups = windowListProvider?() ?? []
        if groups.isEmpty {
            menu.addItem(disabledHeader("No windows", indent: 0))
        } else {
            for (di, display) in groups.enumerated() {
                menu.addItem(disabledHeader("Display \(display.display)", indent: 0))
                for space in display.spaces {
                    menu.addItem(disabledHeader(space.name, indent: 1))
                    for win in space.windows {
                        let label = win.title.isEmpty ? win.app : "\(win.app) — \(win.title)"
                        let item = NSMenuItem(title: truncate(label),
                                              action: #selector(selectWindow(_:)), keyEquivalent: "")
                        item.target = self
                        item.indentationLevel = 2
                        item.representedObject = win.id
                        item.image = appIcon(pid: win.pid)
                        item.state = win.focused ? .on : .off
                        menu.addItem(item)
                    }
                }
                if di < groups.count - 1 { menu.addItem(.separator()) }
            }
        }

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
    }

    @objc private func selectWindow(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? Int { onSelectWindow?(id) }
    }
    @objc private func settingsAction() { onOpenSettings?() }
    @objc private func reregisterAction() { onReregisterSignals?() }
    @objc private func quitAction() { onQuit?() }
}
