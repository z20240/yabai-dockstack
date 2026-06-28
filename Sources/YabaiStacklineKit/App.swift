import AppKit

public enum YabaiStackline {
    public static func versionString() -> String { "yabai-stackline 0.1.0" }

    /// Absolute path to the running binary — used as the yabai signal action target.
    private static func selfBinaryPath() -> String {
        let raw = Bundle.main.executablePath ?? CommandLine.arguments[0]
        return (raw as NSString).standardizingPath
    }

    public static func main() {
        let args = CommandLine.arguments
        let configPath = "~/.config/yabai-stackline/config.json"
        var config = AppConfig.loadFromFile(configPath)

        if args.contains("--refresh") {
            RefreshClient.sendPoke(socketPath: config.socketPath)
            return
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)  // LSUIElement-equivalent at runtime

        // Auto-detect yabai: a valid configured path wins, otherwise search.
        let resolvedYabai = YabaiLocator.resolve(configuredPath: config.yabaiPath) ?? config.yabaiPath
        config.yabaiPath = resolvedYabai
        let client = YabaiClient(yabaiPath: resolvedYabai)

        let renderer = OverlayRenderer(config: config)
        renderer.onClickWindow = { id in client.focus(windowId: id) }

        // replay mode: render once from a JSON file, no live yabai
        if let idx = args.firstIndex(of: "--replay"), idx + 1 < args.count {
            let path = (args[idx + 1] as NSString).expandingTildeInPath
            let data = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
            let stacks = StackBuilder.build(YabaiWindow.decodeList(data))
            renderer.update(stacks)
            app.run()
            return
        }

        let coordinator = RefreshCoordinator(config: config, client: client) { stacks in
            renderer.update(stacks)
        }
        let listener = SignalListener(socketPath: config.socketPath) {
            coordinator.requestRefresh()
        }

        let binaryPath = selfBinaryPath()
        let menu = MenuBarController()

        func refreshMenuStatus() {
            if client.isAvailable() {
                menu.setStatus("yabai: connected ✓")
            } else {
                menu.setStatus("yabai: not found")
            }
            menu.setLoginItemChecked(LoginItem.isEnabled)
        }

        // Auto-register yabai signals (idempotent) so the user never edits yabairc.
        func installSignals() {
            guard client.isAvailable() else { return }
            SignalInstaller.install(client: client, appBinaryPath: binaryPath)
        }

        menu.onQuit = { listener.stop(); coordinator.stop(); app.terminate(nil) }
        menu.onReload = {
            config = AppConfig.loadFromFile(configPath)
            config.yabaiPath = resolvedYabai
            renderer.updateConfig(config)
            coordinator.requestRefresh()
            refreshMenuStatus()
        }
        menu.onToggleStyle = {
            config.style = (config.style == .icon) ? .flag : .icon
            config.save(to: configPath)
            renderer.updateConfig(config)
            coordinator.requestRefresh()
        }
        menu.onReregisterSignals = {
            installSignals()
            coordinator.requestRefresh()
            refreshMenuStatus()
        }
        menu.onToggleLoginItem = {
            _ = LoginItem.setEnabled(!LoginItem.isEnabled)
            menu.setLoginItemChecked(LoginItem.isEnabled)
        }

        // observe display changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { _ in coordinator.requestRefresh() }

        installSignals()
        refreshMenuStatus()
        listener.start()
        coordinator.start()
        _ = menu  // retain
        app.run()
    }
}
