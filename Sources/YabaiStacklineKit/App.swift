import AppKit

public enum YabaiStackline {
    public static func versionString() -> String { "yabai-stackline 0.1.0" }

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

        let client = YabaiClient(yabaiPath: config.yabaiPath)
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

        let menu = MenuBarController()
        menu.onQuit = { listener.stop(); coordinator.stop(); app.terminate(nil) }
        menu.onReload = {
            config = AppConfig.loadFromFile(configPath)
            renderer.updateConfig(config)
            coordinator.requestRefresh()
        }
        menu.onToggleStyle = {
            config.style = (config.style == .icon) ? .flag : .icon
            config.save(to: configPath)
            renderer.updateConfig(config)
            coordinator.requestRefresh()
        }

        // observe display changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { _ in coordinator.requestRefresh() }

        listener.start()
        coordinator.start()
        _ = menu  // retain
        app.run()
    }
}
