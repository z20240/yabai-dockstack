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

        if args.contains("--refresh") || args.contains("--space-changed") {
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
        func focusWindow(_ id: Int) {
            DispatchQueue.global(qos: .userInitiated).async { client.focus(windowId: id) }
        }
        renderer.onClickWindow = { id in focusWindow(id) }

        // replay mode: render once from a JSON file, no live yabai
        if let idx = args.firstIndex(of: "--replay"), idx + 1 < args.count {
            let path = (args[idx + 1] as NSString).expandingTildeInPath
            let data = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
            let stacks = StackBuilder.build(VisibleSpaceFilter.apply(YabaiWindow.decodeList(data)))
            renderer.update(stacks)
            app.run()
            return
        }

        // Single-instance guard: duplicate login-item registrations (e.g. a dev
        // copy and the installed copy) or session restore can launch a second
        // copy at boot — the newcomer bows out, since the menu bar item, unix
        // socket, and event tap all assume exactly one instance. (--refresh and
        // --replay above are exempt: they don't start the full app.)
        let myPid = ProcessInfo.processInfo.processIdentifier
        let exeName = (Bundle.main.executableURL
            ?? URL(fileURLWithPath: CommandLine.arguments[0])).lastPathComponent
        if let other = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier != myPid && $0.executableURL?.lastPathComponent == exeName
        }) {
            NSLog("yabai-dockstack: another instance is already running (pid %d) — exiting",
                  other.processIdentifier)
            return
        }

        // Resolve skhd binary and config paths; build the config engine.
        let skhdPath = ["/opt/homebrew/bin/skhd", "/usr/local/bin/skhd"]
            .first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/skhd"
        let yabaiRcPath = RcDetector.detect(.yabai)
        let skhdRcPath = RcDetector.detect(.skhd)
        let configEngine = ConfigEngine(yabaiPath: resolvedYabai, skhdPath: skhdPath,
                                        yabaiConfigPath: yabaiRcPath, skhdConfigPath: skhdRcPath,
                                        scriptsDir: ConfigPaths.scriptsDir,
                                        manageYabaiConfig: config.manageYabaiConfig,
                                        manageSkhdConfig: config.manageSkhdConfig)

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

        // Dock window previews (gated; needs Accessibility + Screen Recording).
        let thumbCache = ThumbnailCache()
        var dockController: DockPreviewController?

        // AltTab-style window switcher: hold-to-cycle via a global event tap,
        // plus a sticky mode reachable through the show-switcher socket command.
        // The tap is gated on yabai being present so a captured ⌘⇥ can never
        // black-hole the system switcher while yabai is down (5s heal re-checks).
        let switcher = SwitcherController(client: client, cache: thumbCache, config: config)
        let switcherTap = SwitcherKeyTap()
        switcher.onDismiss = { switcherTap.resetMachine() }
        func ensureSwitcherTap() {
            let wanted = config.switcherEnabled && config.switcherHoldToCycle
                && PermissionsHelper.hasAccessibility() && client.isAvailable()
            if wanted {
                switcherTap.updateTriggers(SwitcherTriggers.build(from: config))
                _ = switcherTap.start()
            } else {
                switcherTap.stop()
            }
        }

        let coordinator = RefreshCoordinator(config: config, client: client) { stacks in
            renderer.update(stacks)
            dockController?.warmCache()
        }
        let strip = WindowStripController(client: client)
        strip.setEnabled(config.windowStrip)
        strip.setScale(config.windowStripScale)
        coordinator.onWindows = { windows in
            switcher.noteWindows(windows)
            strip.update(windows: windows)
        }
        switcherTap.onOutput = { output in
            switch output {
            case let .activate(idx, backward):
                let scope = switcherTap.triggers.indices.contains(idx)
                    ? switcherTap.triggers[idx].scope : .allWindows
                if !switcher.open(scope: scope, sticky: false, backward: backward) {
                    // Nothing to show (e.g. window list not warmed yet): stop
                    // swallowing keys and warm the cache for the next attempt.
                    switcherTap.resetMachine()
                    coordinator.requestRefresh()
                }
            case let .cycle(forward): switcher.cycle(forward: forward)
            case let .move(dx, dy): switcher.move(dx: dx, dy: dy)
            case .commit: switcher.commit()
            case .cancel: switcher.cancel()
            case .closeSelected: switcher.closeSelected()
            case .quitSelected: switcher.quitSelected()
            case .pass, .swallow: break
            }
        }
        // ⌃-drag on a stack indicator: replay the move as adjacent yabai swaps,
        // then hand focus back to whichever window had it before.
        renderer.onReorder = { ids, from, to in
            DispatchQueue.global(qos: .userInitiated).async {
                let focused = client.queryFocusedWindow()?.id
                for step in StackReorderPlanner.swaps(ids: ids, from: from, to: to) {
                    client.swap(windowId: step.a, with: step.b)
                }
                if let focused, client.queryFocusedWindow()?.id != focused {
                    client.focus(windowId: focused)
                }
                coordinator.requestRefresh()
            }
        }
        // Hyper Key: always applied at launch — with "none" this also removes a
        // mapping left behind by a crash, so the source key is never stuck as F18.
        let hyperKey = HyperKeyController()
        func applyHyperKey() {
            Hotkey.showHyperSymbol = config.hyperShowSymbol
            hyperKey.apply(source: HyperSource(rawValue: config.hyperKey) ?? .none,
                           quickPress: HyperQuickPress(rawValue: config.hyperQuickPress) ?? .none,
                           includeShift: config.hyperIncludeShift)
        }
        applyHyperKey()
        // Auto padding: yabai paddings sized for our overlays, runtime only.
        let autoPadding = AutoPaddingController(client: client)
        func applyAutoPadding() {
            autoPadding.update(enabled: config.autoPadding, cellSize: config.cellSize,
                               stripEnabled: config.windowStrip, stripScale: config.windowStripScale)
        }
        applyAutoPadding()
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            hyperKey.shutdown()
            autoPadding.restore()
        }
        // SIGTERM/SIGINT skip willTerminate; restore the source key on those too.
        var signalSources: [DispatchSourceSignal] = []
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { hyperKey.shutdown(); autoPadding.restore(); exit(0) }
            src.resume()
            signalSources.append(src)
        }
        let spaceMover = SpaceMover(client: client)
        let windowSpaceMover = WindowSpaceMover(client: client, spaceMover: spaceMover)
        switcher.mover = windowSpaceMover
        // Same as the switcher: with the scripting addition, follow only if asked
        // to (otherwise an instant move, no space switch); without it the
        // SIP-free walk always ends on the target.
        strip.onDropToSpace = { id, space in
            windowSpaceMover.move(windowId: id, toSpace: space, follow: config.switcherFollowMove)
        }
        let menu = MenuBarController()
        let listener = SignalListener(
            socketPath: config.socketPath,
            onPoke: { coordinator.requestRefresh() },
            onCommand: { cmd in
                if cmd == "show-menu" {
                    DispatchQueue.main.async { menu.openMenu() }
                } else if cmd == "show-switcher" {
                    DispatchQueue.main.async {
                        if switcher.isOpen {
                            switcher.cancel()
                        } else {
                            switcher.open(scope: .allWindows, sticky: true)
                        }
                    }
                } else if cmd == "space-changed" {
                    DispatchQueue.main.async {
                        switcher.noteActiveSpaceChanged()
                        coordinator.requestRefresh()
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
        menu.onSelectWindow = { id in focusWindow(id) }
        menu.openOnHover = config.menuOpenOnHover
        strip.onOverflowClick = { menu.openMenu() }
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
                configEngine.manageYabaiConfig = config.manageYabaiConfig
                configEngine.manageSkhdConfig = config.manageSkhdConfig
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
                menu.openOnHover = config.menuOpenOnHover
                strip.setEnabled(config.windowStrip)
                strip.setScale(config.windowStripScale)
                applyHyperKey()
                applyAutoPadding()
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
        menu.onQuit = { listener.stop(); coordinator.stop(); hyperKey.shutdown(); autoPadding.restore(); app.terminate(nil) }
        menu.onRestart = {
            listener.stop(); coordinator.stop(); hyperKey.shutdown(); autoPadding.restore()
            Relauncher.schedule()
            app.terminate(nil)
        }
        menu.onOpenSettings = { settings.show() }
        menu.onOpenYabaiSetup = { yabaiGuide.show() }
        menu.onReregisterSignals = {
            installSignals()
            coordinator.requestRefresh()
        }

        // observe display changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { _ in
                coordinator.requestRefresh()
            }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main) { _ in
                switcher.noteActiveSpaceChanged()
                coordinator.requestRefresh()
            }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main) { _ in switcher.refreshWallpaper() }

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
            // Start the Hyper Key once Accessibility is granted (no relaunch);
            // stop it — restoring the key — if Accessibility is revoked.
            switch HyperKeyPlan.health(configured: HyperSource(rawValue: config.hyperKey) ?? .none,
                                       ax: PermissionsHelper.hasAccessibility(),
                                       running: hyperKey.isRunning) {
            case .start, .stop: applyHyperKey()
            case .keep: break
            }
            guard client.isAvailable() else { return }
            autoPadding.heal()  // a yabai restart reloads yabairc over our paddings
            if !SignalInstaller.isInstalled(client: client) {
                installSignals()
                coordinator.requestRefresh()
            }
        }
        RunLoop.main.add(signalHealth, forMode: .common)

        _ = menu  // retain
        _ = signalSources
        app.run()
    }
}
