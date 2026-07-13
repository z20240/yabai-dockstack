import AppKit

public enum YabaiDockstack {
    public static func versionString() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "yabai-dockstack \(v)"
    }

    /// Absolute path to the running binary — used as the yabai signal action target.
    private static func selfBinaryPath() -> String {
        let raw = Bundle.main.executablePath ?? CommandLine.arguments[0]
        return (raw as NSString).standardizingPath
    }

    public static func main() {
        let args = CommandLine.arguments
        let configPath = "~/.config/yabai-dockstack/config.json"
        var config = AppConfig.loadFromFile(configPath)
        L10n.current = L10n.resolve(AppLanguage(rawValue: config.language) ?? .auto,
                                    preferred: Locale.preferredLanguages)

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

        // Resolve skhd binary and config paths; build the config engine.
        let skhdPath = ["/opt/homebrew/bin/skhd", "/usr/local/bin/skhd"]
            .first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/skhd"
        let yabaiRcPath = ConfigPaths.resolve(candidates: ConfigPaths.yabaiCandidates)
        let skhdRcPath = ConfigPaths.resolve(candidates: ConfigPaths.skhdCandidates)
        let configEngine = ConfigEngine(yabaiPath: resolvedYabai, skhdPath: skhdPath,
                                        yabaiConfigPath: yabaiRcPath, skhdConfigPath: skhdRcPath,
                                        scriptsDir: ConfigPaths.scriptsDir)

        // Write a default config file on first run so it's discoverable/editable.
        let expandedConfig = (configPath as NSString).expandingTildeInPath
        if !FileManager.default.fileExists(atPath: expandedConfig) {
            config.save(to: configPath)
        }

        // Install/refresh bundled helper scripts (only writes to the scripts dir,
        // never touches the user's rc files). Overwrites when an update ships
        // new script contents.
        if ScriptInstaller.needsUpdate(dir: ConfigPaths.scriptsDir) {
            do { try ScriptInstaller.install(to: ConfigPaths.scriptsDir) }
            catch { NSLog("yabai-dockstack: helper script install failed: \(error)") }
        }

        // One-time migration for existing users: pull recognizable hand-written bindings
        // into the managed region. No region yet => first run; the import writes only if it
        // actually matched something, so clean users' rc files stay untouched. Never auto-applies.
        if !configEngine.hasYabaiRegion() { _ = try? configEngine.importYabai() }
        if !configEngine.hasSkhdRegion()  { _ = try? configEngine.importSkhd()  }

        // Dock window previews (gated; needs Accessibility + Screen Recording).
        let thumbCache = ThumbnailCache()
        var dockController: DockPreviewController?

        // AltTab-style window switcher: hold-to-cycle via a global event tap,
        // plus a sticky mode reachable through the show-switcher socket command.
        let switcher = SwitcherController(client: client, cache: thumbCache, config: config)
        let switcherTap = SwitcherKeyTap()
        switcherTap.onOutput = { output in
            switch output {
            case let .activate(idx, backward):
                let scope = switcherTap.triggers.indices.contains(idx)
                    ? switcherTap.triggers[idx].scope : .allWindows
                if !switcher.open(scope: scope, sticky: false, backward: backward) {
                    switcherTap.resetMachine()
                }
            case let .cycle(forward): switcher.cycle(forward: forward)
            case let .move(dx, dy): switcher.move(dx: dx, dy: dy)
            case .commit: switcher.commit()
            case .cancel: switcher.cancel()
            case .closeSelected: switcher.closeSelected()
            case .pass, .swallow: break
            }
        }
        func ensureSwitcherTap() {
            let wanted = config.switcherEnabled && config.switcherHoldToCycle
                && PermissionsHelper.hasAccessibility()
            if wanted {
                switcherTap.triggers = SwitcherTriggers.build(from: config)
                _ = switcherTap.start()
            } else {
                switcherTap.stop()
            }
        }

        let coordinator = RefreshCoordinator(config: config, client: client) { stacks in
            renderer.update(stacks)
            dockController?.warmCache()
        }
        coordinator.onWindows = { switcher.noteWindows($0) }
        let spaceMover = SpaceMover(client: client)
        let menu = MenuBarController()
        let listener = SignalListener(
            socketPath: config.socketPath,
            onPoke: { coordinator.requestRefresh() },
            onCommand: { cmd in
                if cmd == "show-menu" {
                    DispatchQueue.main.async { menu.openMenu() }
                } else if cmd == "show-switcher" {
                    DispatchQueue.main.async {
                        switcher.open(scope: .allWindows, sticky: true)
                    }
                } else {
                    spaceMover.handle(command: cmd)
                }
            })

        let binaryPath = selfBinaryPath()
        menu.statusProvider = { client.isAvailable() ? L10n.t("ui.menu.yabaiConnected") : L10n.t("ui.menu.yabaiNotFound") }
        menu.windowListProvider = {
            WindowMenuModel.build(client.queryWindows(), spaceLabels: client.querySpaceLabels())
        }
        menu.onSelectWindow = { id in client.focus(windowId: id) }
        menu.permissionWarning = {
            (config.dockPreview && !PermissionsHelper.allGranted)
                ? L10n.t("ui.menu.grantPerms") : nil
        }
        menu.yabaiMissing = { !client.isAvailable() }

        let yabaiGuide = YabaiSetupGuide()

        // Auto-register yabai signals (idempotent) so the user never edits yabairc.
        func installSignals() {
            guard client.isAvailable() else { return }
            SignalInstaller.install(client: client, appBinaryPath: binaryPath)
        }

        // Start/stop the Dock-preview controller to match config + permission state.
        // The watcher needs Accessibility; Screen Recording only affects thumbnails.
        func ensureDockController() {
            if config.dockPreview, PermissionsHelper.hasAccessibility(), dockController == nil {
                let dc = DockPreviewController(client: client, cache: thumbCache)
                dc.start()
                dockController = dc
            } else if !config.dockPreview, let dc = dockController {
                dc.stop(); dockController = nil
            }
        }

        let settings = SettingsWindowController(
            config: config,
            onChange: { newConfig in
                config = newConfig
                // Re-resolve the yabai path (blank field → auto-detect) and apply
                // it live to the shared client, then re-register signals.
                let resolved = YabaiLocator.resolve(configuredPath: config.yabaiPath) ?? config.yabaiPath
                client.path = resolved
                config.save(to: configPath)
                renderer.updateConfig(config)
                coordinator.updateConfig(config)
                installSignals()
                coordinator.requestRefresh()
                ensureDockController()
                switcher.updateConfig(config)
                ensureSwitcherTap()
            },
            onLoginToggle: { enabled in _ = LoginItem.setEnabled(enabled) },
            loginIsEnabled: { LoginItem.isEnabled })

        settings.configEngine = configEngine
        settings.yabaiRawPath = yabaiRcPath
        settings.skhdRawPath = skhdRcPath

        // Permissions section: request the permission AND open the right pane, one
        // at a time (avoids the two prompts colliding at launch).
        settings.permissionStatus = {
            (PermissionsHelper.hasAccessibility(), PermissionsHelper.hasScreenRecording())
        }
        settings.onGrantAccessibility = {
            PermissionsHelper.requestAccessibility()
            PermissionsHelper.openAccessibilitySettings()
        }
        settings.onGrantScreenRecording = {
            PermissionsHelper.requestScreenRecording()
            PermissionsHelper.openScreenRecordingSettings()
        }

        yabaiGuide.onSetPath = { settings.show() }
        menu.onQuit = { listener.stop(); coordinator.stop(); app.terminate(nil) }
        menu.onOpenSettings = { settings.show() }
        menu.onOpenYabaiSetup = { yabaiGuide.show() }
        menu.onReregisterSignals = {
            installSignals()
            coordinator.requestRefresh()
        }

        // observe display changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { _ in coordinator.requestRefresh() }

        ensureDockController()
        ensureSwitcherTap()
        // First-run guidance (deferred so the run loop is active for the modal).
        // yabai missing is the priority — nothing works without it. Otherwise, if
        // previews are on but permissions are missing, open Settings to grant them.
        DispatchQueue.main.async {
            if args.contains("--open-settings") {
                settings.show()   // open Settings on launch (handy for support/testing)
                // Optional "--tab <n>" picks the tab (default: yabai tab).
                var tab = 1
                if let i = args.firstIndex(of: "--tab"), i + 1 < args.count, let n = Int(args[i + 1]) {
                    tab = n
                }
                settings.selectTab(at: tab)

            } else if !client.isAvailable() {
                yabaiGuide.show()
            } else if config.dockPreview && !PermissionsHelper.allGranted {
                settings.show()
            }
        }

        installSignals()
        listener.start()
        coordinator.start()

        // Self-heal: yabai's CLI-registered signals are wiped whenever yabai
        // restarts. Periodically re-add ours if they've gone missing, so the
        // instant event path keeps working without a relaunch.
        let signalHealth = Timer(timeInterval: 5, repeats: true) { _ in
            // Activate Dock previews once Accessibility is granted (no relaunch).
            ensureDockController()
            ensureSwitcherTap()
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
