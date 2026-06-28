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
            let stacks = StackBuilder.build(VisibleSpaceFilter.apply(YabaiWindow.decodeList(data)))
            renderer.update(stacks)
            app.run()
            return
        }

        // Write a default config file on first run so it's discoverable/editable.
        let expandedConfig = (configPath as NSString).expandingTildeInPath
        if !FileManager.default.fileExists(atPath: expandedConfig) {
            config.save(to: configPath)
        }

        // Dock window previews (gated; needs Accessibility + Screen Recording).
        let thumbCache = ThumbnailCache()
        var dockController: DockPreviewController?

        let coordinator = RefreshCoordinator(config: config, client: client) { stacks in
            renderer.update(stacks)
            dockController?.warmCache()
        }
        let listener = SignalListener(socketPath: config.socketPath) {
            coordinator.requestRefresh()
        }

        let binaryPath = selfBinaryPath()
        let menu = MenuBarController()
        menu.statusProvider = { client.isAvailable() ? "yabai: connected ✓" : "yabai: not found" }
        menu.windowListProvider = { WindowMenuModel.build(client.queryWindows()) }
        menu.onSelectWindow = { id in client.focus(windowId: id) }

        // Auto-register yabai signals (idempotent) so the user never edits yabairc.
        func installSignals() {
            guard client.isAvailable() else { return }
            SignalInstaller.install(client: client, appBinaryPath: binaryPath)
        }

        let settings = SettingsWindowController(
            config: config,
            onChange: { newConfig in
                var c = newConfig
                c.yabaiPath = resolvedYabai
                config = c
                config.save(to: configPath)
                renderer.updateConfig(config)
                coordinator.updateConfig(config)
                coordinator.requestRefresh()
            },
            onLoginToggle: { enabled in _ = LoginItem.setEnabled(enabled) },
            loginIsEnabled: { LoginItem.isEnabled })

        menu.onQuit = { listener.stop(); coordinator.stop(); app.terminate(nil) }
        menu.onOpenSettings = { settings.show() }
        menu.onReregisterSignals = {
            installSignals()
            coordinator.requestRefresh()
        }

        // observe display changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { _ in coordinator.requestRefresh() }

        if config.dockPreview {
            if !PermissionsHelper.hasAccessibility() { PermissionsHelper.requestAccessibility() }
            if !PermissionsHelper.hasScreenRecording() { PermissionsHelper.requestScreenRecording() }
            let dc = DockPreviewController(client: client, cache: thumbCache)
            dc.start()
            dockController = dc
        }

        installSignals()
        listener.start()
        coordinator.start()

        // Self-heal: yabai's CLI-registered signals are wiped whenever yabai
        // restarts. Periodically re-add ours if they've gone missing, so the
        // instant event path keeps working without a relaunch.
        let signalHealth = Timer(timeInterval: 5, repeats: true) { _ in
            guard client.isAvailable() else { return }
            if !SignalInstaller.isInstalled(client: client) {
                installSignals()
                coordinator.requestRefresh()
            }
        }
        RunLoop.main.add(signalHealth, forMode: .common)

        _ = menu  // retain
        app.run()
    }
}
