import AppKit
import UniformTypeIdentifiers

/// A simple preferences window so all appearance settings are adjustable from the
/// UI — no config-file editing. Changes apply live and persist via `onChange`.
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var tabView: NSTabView?
    private weak var yabaiPane: YabaiSettingsPaneView?
    private weak var shortcutsPane: ShortcutsPaneView?

    /// Select a tab by index (0=Appearance, 1=yabai, 2=Keyboard, 3=Switcher). Builds the window first.
    public func selectTab(at index: Int) {
        if window == nil { build() }
        if let tv = tabView, index >= 0, index < tv.numberOfTabViewItems {
            tv.selectTabViewItem(at: index)
        }
    }
    private var config: AppConfig
    private let onChange: (AppConfig) -> Void
    private let onLoginToggle: (Bool) -> Void
    private let loginIsEnabled: () -> Bool

    /// Maps `languagePopup` index <-> `AppLanguage`.
    private static let languageOrder: [AppLanguage] = [.auto, .en, .zhHant, .ja]

    // controls
    private let languagePopup = NSPopUpButton()
    private let stylePopup = NSPopUpButton()
    private let sizeSlider = NSSlider()
    private let focusedSlider = NSSlider()
    private let unfocusedSlider = NSSlider()
    private let flagWell = NSColorWell()
    private let backgroundCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let backgroundWell = NSColorWell()
    private let confineCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let autoPaddingCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let clickThroughCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let dragReorderCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let fullWidthPopup = NSPopUpButton()
    private let debounceField = NSTextField()
    private let pollField = NSTextField()
    private let yabaiPathField = NSTextField()
    private let dockPreviewCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let menuHoverCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let menuHoverHelp = NSTextField(labelWithString: "")
    private let windowStripCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let windowStripHelp = NSTextField(wrappingLabelWithString: "")
    private let windowStripSizeSlider = NSSlider(value: 0.8, minValue: 0.5, maxValue: 1.5, target: nil, action: nil)

    private let hyperSourcePopup = NSPopUpButton()
    private let hyperQuickPopup = NSPopUpButton()
    private let hyperShiftCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let hyperSymbolCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let hyperStatus = NSTextField(wrappingLabelWithString: "")
    /// Quick-press choices offered for the current source (toggleCapsLock only for Caps Lock).
    private var hyperQuickChoices: [HyperQuickPress] = []
    private let loginCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    // Switcher tab
    private static let switcherAppearanceOrder = ["thumbnails", "icons", "titles"]
    private let switcherEnableCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let switcherAppearancePopup = NSPopUpButton()
    private let switcherHoldCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let switcherCmdTabCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    /// The search switcher's skhd binding (catalog action open-window-switcher),
    /// the same one the Keyboard tab edits.
    private let switcherSearchRecorder = RecordHotkeyControl(frame: .zero)
    private let switcherSearchHint = NSTextField(wrappingLabelWithString: "")
    private let switcherAllRecorder = RecordHotkeyControl(frame: .zero)
    private let switcherAppRecorder = RecordHotkeyControl(frame: .zero)
    private let switcherSpaceRecorder = RecordHotkeyControl(frame: .zero)
    private let spacesFocusDestinationCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let spacesWallpaperCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let spacesWallpaperPathField = NSTextField()
    private let spacesWallpaperChooseButton = NSButton(title: "", target: nil, action: nil)
    private let spacesWallpaperClearButton = NSButton(title: "", target: nil, action: nil)
    private let spacesWallpaperDarkPathField = NSTextField()
    private let spacesWallpaperDarkChooseButton = NSButton(title: "", target: nil, action: nil)
    private let spacesWallpaperDarkClearButton = NSButton(title: "", target: nil, action: nil)
    // Permissions (for Dock previews)
    private let axStatus = NSTextField(labelWithString: "")
    private let axButton = NSButton(title: "", target: nil, action: nil)
    private let srStatus = NSTextField(labelWithString: "")
    private let srButton = NSButton(title: "", target: nil, action: nil)
    private let permissionBanner = NSView()
    private var permTimer: Timer?

    /// Set by the app BEFORE calling show() — enables the yabai and Keyboard tabs.
    public var configEngine: ConfigEngine?
    public var yabaiRawPath: String?
    public var skhdRawPath: String?

    /// Set by the app: trigger the request + open the right System Settings pane.
    public var onGrantAccessibility: (() -> Void)?
    public var onGrantScreenRecording: (() -> Void)?
    /// Returns (accessibilityGranted, screenRecordingGranted).
    public var permissionStatus: (() -> (Bool, Bool))?

    public init(config: AppConfig,
                onChange: @escaping (AppConfig) -> Void,
                onLoginToggle: @escaping (Bool) -> Void,
                loginIsEnabled: @escaping () -> Bool) {
        self.config = config
        self.onChange = onChange
        self.onLoginToggle = onLoginToggle
        self.loginIsEnabled = loginIsEnabled
        super.init()
    }

    public func updateConfig(_ config: AppConfig) {
        self.config = config
        configEngine?.manageYabaiConfig = config.manageYabaiConfig
        configEngine?.manageSkhdConfig = config.manageSkhdConfig
        yabaiPane?.updateManagementEnabled(config.manageYabaiConfig)
        shortcutsPane?.updateManagementEnabled(config.manageSkhdConfig)
        if window != nil { syncControls() }
    }

    public func show() {
        if window == nil { build() }
        syncControls()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.center()
        startPermTimer()
    }

    // Live-refresh permission status while the window is open (so granting in
    // System Settings and switching back flips the indicator to ✓).
    private func startPermTimer() {
        permTimer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.syncPermissions() }
        RunLoop.main.add(t, forMode: .common)
        permTimer = t
    }

    public func windowWillClose(_ notification: Notification) {
        permTimer?.invalidate(); permTimer = nil
    }

    private func syncPermissions() {
        let (ax, sr) = permissionStatus?() ?? (false, false)
        axStatus.stringValue = ax ? L10n.t("ui.appearance.granted") : L10n.t("ui.appearance.notGranted")
        axStatus.textColor = ax ? .systemGreen : .systemRed
        axButton.isEnabled = !ax
        srStatus.stringValue = sr ? L10n.t("ui.appearance.granted") : L10n.t("ui.appearance.notGranted")
        srStatus.textColor = sr ? .systemGreen : .systemRed
        srButton.isEnabled = !sr
        permissionBanner.isHidden = (ax && sr) || !config.dockPreview
        syncHyperStatus(ax: ax)
    }

    private func syncHyperStatus(ax: Bool) {
        var notes: [String] = []
        if HyperSource(rawValue: config.hyperKey) != HyperSource.none {
            if !ax { notes.append(L10n.t("ui.hyper.needsAccessibility")) }
            if Self.processRunning("karabiner_grabber") {
                notes.append(L10n.t("ui.hyper.karabinerWarning"))
            }
        }
        hyperStatus.stringValue = notes.joined(separator: "\n")
        hyperStatus.isHidden = notes.isEmpty
    }

    /// karabiner_grabber is a root daemon, not an NSRunningApplication — ask pgrep.
    private static func processRunning(_ name: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        p.arguments = ["-x", name]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    private func syncHyperQuickChoices(source: HyperSource) {
        hyperQuickChoices = source == .capsLock ? HyperQuickPress.allCases : [.none, .escape]
        hyperQuickPopup.removeAllItems()
        hyperQuickPopup.addItems(withTitles: hyperQuickChoices.map { L10n.t("ui.hyper.quick.\($0.rawValue)") })
        let current = HyperQuickPress(rawValue: config.hyperQuickPress) ?? .none
        hyperQuickPopup.selectItem(at: hyperQuickChoices.firstIndex(of: current) ?? 0)
    }

    // MARK: - Build

    private func row(_ label: String, _ control: NSView) -> [NSView] {
        let l = NSTextField(labelWithString: label)
        l.alignment = .right
        return [l, control]
    }

    /// One-time setup: window shell + control wiring (target/action) that never
    /// changes across a language switch. Constructs the initial content via
    /// `buildContent()`.
    private func build() {
        NSColorPanel.shared.showsAlpha = true

        languagePopup.target = self; languagePopup.action = #selector(languageChanged)
        stylePopup.target = self; stylePopup.action = #selector(changed)

        sizeSlider.minValue = 12; sizeSlider.maxValue = 48
        sizeSlider.target = self; sizeSlider.action = #selector(changed)

        for s in [focusedSlider, unfocusedSlider] {
            s.minValue = 0.1; s.maxValue = 1.0
            s.target = self; s.action = #selector(changed)
        }

        flagWell.target = self; flagWell.action = #selector(changed)
        backgroundWell.target = self; backgroundWell.action = #selector(changed)
        backgroundCheck.target = self; backgroundCheck.action = #selector(changed)
        confineCheck.target = self; confineCheck.action = #selector(changed)
        autoPaddingCheck.target = self; autoPaddingCheck.action = #selector(changed)
        clickThroughCheck.target = self; clickThroughCheck.action = #selector(changed)
        dragReorderCheck.target = self; dragReorderCheck.action = #selector(changed)
        dockPreviewCheck.target = self; dockPreviewCheck.action = #selector(changed)
        menuHoverCheck.target = self; menuHoverCheck.action = #selector(changed)
        menuHoverHelp.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        menuHoverHelp.textColor = .secondaryLabelColor
        windowStripCheck.target = self; windowStripCheck.action = #selector(changed)
        windowStripSizeSlider.target = self; windowStripSizeSlider.action = #selector(changed)
        windowStripSizeSlider.isContinuous = true
        windowStripSizeSlider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        windowStripHelp.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        windowStripHelp.textColor = .secondaryLabelColor
        windowStripHelp.preferredMaxLayoutWidth = 340
        hyperSourcePopup.target = self; hyperSourcePopup.action = #selector(changed)
        hyperQuickPopup.target = self; hyperQuickPopup.action = #selector(changed)
        hyperShiftCheck.target = self; hyperShiftCheck.action = #selector(changed)
        hyperSymbolCheck.target = self; hyperSymbolCheck.action = #selector(changed)
        hyperStatus.font = .systemFont(ofSize: 11)
        hyperStatus.textColor = .systemOrange
        loginCheck.target = self; loginCheck.action = #selector(loginChanged)

        fullWidthPopup.target = self; fullWidthPopup.action = #selector(changed)

        switcherEnableCheck.target = self; switcherEnableCheck.action = #selector(changed)
        switcherAppearancePopup.target = self; switcherAppearancePopup.action = #selector(changed)
        switcherHoldCheck.target = self; switcherHoldCheck.action = #selector(changed)
        switcherCmdTabCheck.target = self; switcherCmdTabCheck.action = #selector(changed)
        spacesFocusDestinationCheck.target = self; spacesFocusDestinationCheck.action = #selector(changed)
        spacesWallpaperCheck.target = self; spacesWallpaperCheck.action = #selector(changed)
        spacesWallpaperChooseButton.target = self; spacesWallpaperChooseButton.action = #selector(chooseWallpaper)
        spacesWallpaperClearButton.target = self; spacesWallpaperClearButton.action = #selector(clearWallpaper)
        spacesWallpaperDarkChooseButton.target = self; spacesWallpaperDarkChooseButton.action = #selector(chooseDarkWallpaper)
        spacesWallpaperDarkClearButton.target = self; spacesWallpaperDarkClearButton.action = #selector(clearDarkWallpaper)
        func wireRecorder(_ r: RecordHotkeyControl, _ kp: WritableKeyPath<AppConfig, String>) {
            r.onChange = { [weak self] hk in
                guard let self else { return }
                self.config[keyPath: kp] = hk?.skhdString ?? ""
                self.onChange(self.config)
            }
        }
        wireRecorder(switcherAllRecorder, \.switcherHotkeyAll)
        wireRecorder(switcherAppRecorder, \.switcherHotkeyApp)
        wireRecorder(switcherSpaceRecorder, \.switcherHotkeySpace)
        switcherSearchRecorder.onChange = { [weak self] hk in
            guard let engine = self?.configEngine, engine.manageSkhdConfig else { return }
            let bindings = ShortcutBindings.setting(engine.loadBindingsOrDefault(),
                                                    action: "open-window-switcher", hotkey: hk)
            do {
                try engine.saveSkhd(bindings)
                _ = engine.applySkhd()
            } catch {
                NSLog("yabai-dockstack: saving the search switcher hotkey failed: \(error)")
            }
            // The Keyboard tab holds its own copy of the bindings — rebuild it so
            // a later Apply there doesn't revert this.
            guard let self else { return }
            let selected = self.tabView.flatMap { tv in tv.selectedTabViewItem.map { tv.indexOfTabViewItem($0) } } ?? 0
            self.buildContent()
            self.tabView?.selectTabViewItem(at: selected)
            self.syncControls()
        }

        for f in [debounceField, pollField] {
            f.alignment = .right
            f.target = self; f.action = #selector(changed)
            f.widthAnchor.constraint(equalToConstant: 80).isActive = true
        }

        yabaiPathField.target = self; yabaiPathField.action = #selector(changed)
        yabaiPathField.widthAnchor.constraint(equalToConstant: 240).isActive = true

        sizeSlider.widthAnchor.constraint(equalToConstant: 200).isActive = true

        axButton.target = self; axButton.action = #selector(grantAX)
        srButton.target = self; srButton.action = #selector(grantSR)
        axButton.controlSize = .small; srButton.controlSize = .small

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                           styleMask: [.titled, .closable],
                           backing: .buffered, defer: false)
        win.isReleasedWhenClosed = false
        win.delegate = self
        window = win

        buildContent()
    }

    /// (Re-)constructs the tab view + panes from the current language table and
    /// installs it as the window's content view. Re-callable on language change —
    /// preserves the selected tab and control *values* (via `syncControls()`,
    /// called by the caller after this returns).
    private func buildContent() {
        languagePopup.removeAllItems()
        languagePopup.addItems(withTitles: [
            L10n.t("ui.language.auto"), "English", "繁體中文", "日本語",
        ])

        stylePopup.removeAllItems()
        stylePopup.addItems(withTitles: [L10n.t("ui.appearance.styleIcon"), L10n.t("ui.appearance.styleFlag")])

        fullWidthPopup.removeAllItems()
        fullWidthPopup.addItems(withTitles: [L10n.t("ui.appearance.left"), L10n.t("ui.appearance.right")])

        backgroundCheck.title = L10n.t("ui.appearance.showBackground")
        confineCheck.title = L10n.t("ui.appearance.confine")
        autoPaddingCheck.title = L10n.t("ui.appearance.autoPadding")
        clickThroughCheck.title = L10n.t("ui.appearance.clickThrough")
        dragReorderCheck.title = L10n.t("ui.appearance.dragReorder")
        dockPreviewCheck.title = L10n.t("ui.appearance.dockPreview")
        menuHoverCheck.title = L10n.t("ui.appearance.menuHover")
        windowStripCheck.title = L10n.t("ui.appearance.windowStrip")
        windowStripHelp.stringValue = L10n.t("ui.appearance.windowStripHelp")
        // Surface the existing open-menu hotkey so it's discoverable.
        let bindings = configEngine?.loadBindingsOrDefault() ?? []
        func boundKey(_ action: String) -> Hotkey? {
            bindings.first { $0.actionID == action && $0.enabled }?.hotkey
        }
        menuHoverHelp.stringValue = boundKey("open-window-menu").map {
            String(format: L10n.t("ui.appearance.menuHoverHelp"), $0.displayString)
        } ?? ""
        switcherSearchRecorder.hotkey = boundKey("open-window-switcher")
        syncSkhdManagementControls()
        loginCheck.title = L10n.t("ui.appearance.login")

        yabaiPathField.placeholderString = L10n.t("ui.appearance.autoDetect")

        axButton.title = L10n.t("ui.appearance.grant")
        srButton.title = L10n.t("ui.appearance.grant")
        let axCell = NSStackView(views: [axStatus, axButton]); axCell.spacing = 8
        let srCell = NSStackView(views: [srStatus, srButton]); srCell.spacing = 8

        let grid = NSGridView(views: [
            row(L10n.t("ui.appearance.language"), languagePopup),
            row(L10n.t("ui.appearance.accessibility"), axCell),
            row(L10n.t("ui.appearance.screenRecording"), srCell),
            row(L10n.t("ui.appearance.style"), stylePopup),
            row(L10n.t("ui.appearance.size"), sizeSlider),
            row(L10n.t("ui.appearance.focusedOpacity"), focusedSlider),
            row(L10n.t("ui.appearance.unfocusedOpacity"), unfocusedSlider),
            row(L10n.t("ui.appearance.flagColor"), flagWell),
            [NSGridCell.emptyContentView, backgroundCheck],
            row(L10n.t("ui.appearance.backgroundColor"), backgroundWell),
            [NSGridCell.emptyContentView, confineCheck],
            [NSGridCell.emptyContentView, autoPaddingCheck],
            [NSGridCell.emptyContentView, clickThroughCheck],
            [NSGridCell.emptyContentView, dragReorderCheck],
            [NSGridCell.emptyContentView, dockPreviewCheck],
            [NSGridCell.emptyContentView, menuHoverCheck],
            [NSGridCell.emptyContentView, menuHoverHelp],
            [NSGridCell.emptyContentView, windowStripCheck],
            row(L10n.t("ui.appearance.windowStripSize"), windowStripSizeSlider),
            [NSGridCell.emptyContentView, windowStripHelp],
            row(L10n.t("ui.appearance.fullWidthSide"), fullWidthPopup),
            row(L10n.t("ui.appearance.debounce"), debounceField),
            row(L10n.t("ui.appearance.poll"), pollField),
            row(L10n.t("ui.appearance.yabaiPath"), yabaiPathField),
            [NSGridCell.emptyContentView, loginCheck],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.column(at: 0).xPlacement = NSGridCell.Placement.trailing
        grid.rowAlignment = NSGridRow.Alignment.firstBaseline
        grid.columnSpacing = 12
        grid.rowSpacing = 12

        // Prominent warning banner, shown only when a required permission is missing.
        permissionBanner.wantsLayer = true
        permissionBanner.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.22).cgColor
        permissionBanner.layer?.cornerRadius = 8
        for sub in permissionBanner.subviews { sub.removeFromSuperview() }
        let bannerLabel = NSTextField(wrappingLabelWithString: L10n.t("ui.appearance.permWarning"))
        bannerLabel.font = .systemFont(ofSize: 12, weight: .medium)
        bannerLabel.translatesAutoresizingMaskIntoConstraints = false
        permissionBanner.addSubview(bannerLabel)
        NSLayoutConstraint.activate([
            bannerLabel.leadingAnchor.constraint(equalTo: permissionBanner.leadingAnchor, constant: 12),
            bannerLabel.trailingAnchor.constraint(equalTo: permissionBanner.trailingAnchor, constant: -12),
            bannerLabel.topAnchor.constraint(equalTo: permissionBanner.topAnchor, constant: 8),
            bannerLabel.bottomAnchor.constraint(equalTo: permissionBanner.bottomAnchor, constant: -8),
        ])

        let stack = NSStackView(views: [permissionBanner, grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        // --- Appearance tab: reparent existing stack into a plain container ---
        let appearancePane = NSView()
        appearancePane.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: appearancePane.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: appearancePane.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: appearancePane.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: appearancePane.bottomAnchor, constant: -20),
            permissionBanner.widthAnchor.constraint(equalTo: grid.widthAnchor),
        ])

        let appearanceItem = NSTabViewItem()
        appearanceItem.label = L10n.t("ui.tab.appearance")
        appearanceItem.view = appearancePane

        // --- yabai tab ---
        let yabaiItem = NSTabViewItem()
        yabaiItem.label = L10n.t("ui.tab.yabai")
        if let engine = configEngine {
            engine.manageYabaiConfig = config.manageYabaiConfig
            let pane = YabaiSettingsPaneView(engine: engine, rawFilePath: yabaiRawPath ?? "") { [weak self] enabled in
                guard let self else { return }
                self.config.manageYabaiConfig = enabled
                self.onChange(self.config)
            }
            yabaiPane = pane
            yabaiItem.view = pane
        } else {
            yabaiItem.view = makePlaceholder(L10n.t("ui.yabai.notConfigured"))
        }

        // --- Keyboard tab ---
        let keyboardItem = NSTabViewItem()
        keyboardItem.label = L10n.t("ui.tab.keyboard")
        if let engine = configEngine {
            engine.manageSkhdConfig = config.manageSkhdConfig
            let pane = ShortcutsPaneView(engine: engine, rawFilePath: skhdRawPath ?? "") { [weak self] enabled in
                guard let self else { return }
                self.config.manageSkhdConfig = enabled
                self.syncSkhdManagementControls()
                self.onChange(self.config)
            }
            shortcutsPane = pane
            keyboardItem.view = pane
        } else {
            keyboardItem.view = makePlaceholder(L10n.t("ui.keyboard.notConfigured"))
        }

        // --- Switcher tab ---
        switcherAppearancePopup.removeAllItems()
        switcherAppearancePopup.addItems(withTitles: [
            L10n.t("ui.switcher.appearanceThumbnails"),
            L10n.t("ui.switcher.appearanceIcons"),
            L10n.t("ui.switcher.appearanceTitles"),
        ])
        switcherEnableCheck.title = L10n.t("ui.switcher.enable")
        switcherHoldCheck.title = L10n.t("ui.switcher.holdToCycle")
        switcherCmdTabCheck.title = L10n.t("ui.switcher.captureCmdTab")
        spacesFocusDestinationCheck.title = L10n.t("ui.spaces.focusDestination")
        spacesWallpaperCheck.title = L10n.t("ui.spaces.wallpaper")
        spacesWallpaperChooseButton.title = L10n.t("ui.spaces.chooseWallpaper")
        spacesWallpaperClearButton.title = L10n.t("ui.spaces.clearWallpaper")
        spacesWallpaperPathField.placeholderString = L10n.t("ui.spaces.wallpaperPath")
        spacesWallpaperPathField.isEditable = false
        spacesWallpaperPathField.lineBreakMode = .byTruncatingMiddle
        spacesWallpaperDarkChooseButton.title = L10n.t("ui.spaces.chooseWallpaper")
        spacesWallpaperDarkClearButton.title = L10n.t("ui.spaces.clearWallpaper")
        spacesWallpaperDarkPathField.placeholderString = L10n.t("ui.spaces.darkWallpaperPath")
        spacesWallpaperDarkPathField.isEditable = false
        spacesWallpaperDarkPathField.lineBreakMode = .byTruncatingMiddle
        let wallpaperControls = NSStackView(views: [spacesWallpaperPathField,
                                  spacesWallpaperChooseButton,
                                  spacesWallpaperClearButton])
        wallpaperControls.spacing = 6
        wallpaperControls.alignment = .centerY
        let darkWallpaperControls = NSStackView(views: [spacesWallpaperDarkPathField,
                                 spacesWallpaperDarkChooseButton,
                                 spacesWallpaperDarkClearButton])
        darkWallpaperControls.spacing = 6
        darkWallpaperControls.alignment = .centerY

        let switcherGrid = NSGridView(views: [
            [NSGridCell.emptyContentView, switcherEnableCheck],
            row(L10n.t("ui.switcher.appearance"), switcherAppearancePopup),
            [NSGridCell.emptyContentView, switcherHoldCheck],
            row(L10n.t("ui.switcher.hotkeyAll"), switcherAllRecorder),
            row(L10n.t("ui.switcher.hotkeyApp"), switcherAppRecorder),
            row(L10n.t("ui.switcher.hotkeySpace"), switcherSpaceRecorder),
            row(L10n.t("ui.switcher.hotkeySearch"), switcherSearchRecorder),
            [NSGridCell.emptyContentView, switcherSearchHint],
            [NSGridCell.emptyContentView, switcherCmdTabCheck],
            [NSGridCell.emptyContentView, spacesFocusDestinationCheck],
            [NSGridCell.emptyContentView, spacesWallpaperCheck],
            row(L10n.t("ui.spaces.wallpaperPath"), wallpaperControls),
            row(L10n.t("ui.spaces.darkWallpaperPath"), darkWallpaperControls),
        ])
        switcherGrid.translatesAutoresizingMaskIntoConstraints = false
        switcherGrid.column(at: 0).xPlacement = NSGridCell.Placement.trailing
        switcherGrid.rowAlignment = NSGridRow.Alignment.firstBaseline
        switcherGrid.columnSpacing = 12
        switcherGrid.rowSpacing = 12

        let switcherHint = NSTextField(wrappingLabelWithString: L10n.t("ui.switcher.hint"))
        switcherHint.font = .systemFont(ofSize: 11)
        // Wrap at a fixed width instead of stretching the grid (labels would
        // drift right as the window widens).
        switcherHint.preferredMaxLayoutWidth = 460
        switcherGrid.setContentHuggingPriority(.required, for: .horizontal)
        switcherHint.textColor = .secondaryLabelColor

        let switcherStack = NSStackView(views: [switcherGrid, switcherHint])
        switcherStack.orientation = .vertical
        switcherStack.alignment = .leading
        switcherStack.spacing = 14
        switcherStack.translatesAutoresizingMaskIntoConstraints = false

        let switcherPane = NSView()
        switcherPane.addSubview(switcherStack)
        NSLayoutConstraint.activate([
            switcherStack.leadingAnchor.constraint(equalTo: switcherPane.leadingAnchor, constant: 20),
            switcherStack.trailingAnchor.constraint(equalTo: switcherPane.trailingAnchor, constant: -20),
            switcherStack.topAnchor.constraint(equalTo: switcherPane.topAnchor, constant: 20),
            switcherStack.bottomAnchor.constraint(lessThanOrEqualTo: switcherPane.bottomAnchor, constant: -20),
            switcherHint.widthAnchor.constraint(lessThanOrEqualTo: switcherStack.widthAnchor),
        ])

        let switcherItem = NSTabViewItem()
        switcherItem.label = L10n.t("ui.tab.switcher")
        switcherItem.view = switcherPane

        // --- Hyper Key tab ---
        hyperSourcePopup.removeAllItems()
        hyperSourcePopup.addItems(withTitles: HyperSource.allCases.map { L10n.t("ui.hyper.source.\($0.rawValue)") })
        hyperShiftCheck.title = L10n.t("ui.hyper.includeShift")
        hyperSymbolCheck.title = L10n.t("ui.hyper.showSymbol")
        let hyperGrid = NSGridView(views: [
            row(L10n.t("ui.hyper.key"), hyperSourcePopup),
            row(L10n.t("ui.hyper.quickPress"), hyperQuickPopup),
            [NSGridCell.emptyContentView, hyperShiftCheck],
            [NSGridCell.emptyContentView, hyperSymbolCheck],
        ])
        hyperGrid.translatesAutoresizingMaskIntoConstraints = false
        hyperGrid.column(at: 0).xPlacement = NSGridCell.Placement.trailing
        hyperGrid.rowAlignment = NSGridRow.Alignment.firstBaseline
        hyperGrid.columnSpacing = 12
        hyperGrid.rowSpacing = 12
        let hyperHelp = NSTextField(wrappingLabelWithString: L10n.t("ui.hyper.help"))
        hyperHelp.font = .systemFont(ofSize: 11)
        hyperHelp.textColor = .secondaryLabelColor
        hyperHelp.preferredMaxLayoutWidth = 460
        hyperStatus.preferredMaxLayoutWidth = 460
        hyperGrid.setContentHuggingPriority(.required, for: .horizontal)
        let hyperStack = NSStackView(views: [hyperGrid, hyperHelp, hyperStatus])
        hyperStack.orientation = .vertical
        hyperStack.alignment = .leading
        hyperStack.spacing = 14
        hyperStack.translatesAutoresizingMaskIntoConstraints = false
        let hyperPane = NSView()
        hyperPane.addSubview(hyperStack)
        NSLayoutConstraint.activate([
            hyperStack.leadingAnchor.constraint(equalTo: hyperPane.leadingAnchor, constant: 20),
            hyperStack.trailingAnchor.constraint(equalTo: hyperPane.trailingAnchor, constant: -20),
            hyperStack.topAnchor.constraint(equalTo: hyperPane.topAnchor, constant: 20),
            hyperStack.bottomAnchor.constraint(lessThanOrEqualTo: hyperPane.bottomAnchor, constant: -20),
            hyperHelp.widthAnchor.constraint(lessThanOrEqualTo: hyperStack.widthAnchor),
            hyperStatus.widthAnchor.constraint(lessThanOrEqualTo: hyperStack.widthAnchor),
        ])
        let hyperItem = NSTabViewItem()
        hyperItem.label = L10n.t("ui.tab.hyper")
        hyperItem.view = hyperPane

        // --- NSTabView as the window's content view ---
        let tabView = NSTabView()
        tabView.addTabViewItem(appearanceItem)
        tabView.addTabViewItem(yabaiItem)
        tabView.addTabViewItem(keyboardItem)
        tabView.addTabViewItem(switcherItem)
        tabView.addTabViewItem(hyperItem)
        tabView.delegate = self
        self.tabView = tabView

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        window?.title = L10n.t("ui.windowTitle") + (version.map { " (v\($0))" } ?? "")
        window?.contentView = tabView
    }

    private func makePlaceholder(_ text: String) -> NSView {
        let view = NSView()
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }

    private func syncControls() {
        syncSkhdManagementControls()
        let langIndex = Self.languageOrder.firstIndex(of: AppLanguage(rawValue: config.language) ?? .auto) ?? 0
        languagePopup.selectItem(at: langIndex)
        stylePopup.selectItem(at: config.style == .flag ? 1 : 0)
        sizeSlider.doubleValue = config.cellSize
        focusedSlider.doubleValue = config.focusedAlpha
        unfocusedSlider.doubleValue = config.unfocusedAlpha
        flagWell.color = NSColor.fromHex(config.flagColor, fallback: .systemBlue)
        backgroundCheck.state = config.showBackground ? .on : .off
        backgroundWell.color = NSColor.fromHex(config.backgroundColor, fallback: NSColor(white: 0, alpha: 0.8))
        confineCheck.state = config.confineToGap ? .on : .off
        autoPaddingCheck.state = config.autoPadding ? .on : .off
        clickThroughCheck.state = config.indicatorClickThrough ? .on : .off
        dragReorderCheck.state = config.indicatorDragReorder ? .on : .off
        dragReorderCheck.isEnabled = !config.indicatorClickThrough
        dockPreviewCheck.state = config.dockPreview ? .on : .off
        menuHoverCheck.state = config.menuOpenOnHover ? .on : .off
        let hyperSource = HyperSource(rawValue: config.hyperKey) ?? .none
        hyperSourcePopup.selectItem(at: HyperSource.allCases.firstIndex(of: hyperSource) ?? 0)
        syncHyperQuickChoices(source: hyperSource)
        hyperShiftCheck.state = config.hyperIncludeShift ? .on : .off
        hyperSymbolCheck.state = config.hyperShowSymbol ? .on : .off
        let hyperOff = hyperSource == .none
        hyperQuickPopup.isEnabled = !hyperOff
        hyperShiftCheck.isEnabled = !hyperOff
        windowStripCheck.state = config.windowStrip ? .on : .off
        windowStripSizeSlider.doubleValue = config.windowStripScale
        windowStripSizeSlider.isEnabled = config.windowStrip
        fullWidthPopup.selectItem(at: config.fullWidthSide == "right" ? 1 : 0)
        debounceField.integerValue = Int((config.debounceSeconds * 1000).rounded())
        pollField.integerValue = Int((config.pollSeconds * 1000).rounded())
        yabaiPathField.stringValue = config.yabaiPath
        loginCheck.state = loginIsEnabled() ? .on : .off
        switcherEnableCheck.state = config.switcherEnabled ? .on : .off
        let appearanceIdx = Self.switcherAppearanceOrder.firstIndex(of: config.switcherAppearance) ?? 0
        switcherAppearancePopup.selectItem(at: appearanceIdx)
        switcherHoldCheck.state = config.switcherHoldToCycle ? .on : .off
        switcherCmdTabCheck.state = config.switcherCaptureCmdTab ? .on : .off
        // ⌘⇥ capture rides on the hold-to-cycle tap; make the dependency visible.
        switcherCmdTabCheck.isEnabled = config.switcherEnabled && config.switcherHoldToCycle
        spacesFocusDestinationCheck.state = config.switcherFollowMove ? .on : .off
        spacesWallpaperCheck.state = config.switcherWallpaper ? .on : .off
        spacesWallpaperPathField.stringValue = config.switcherWallpaperPath
        spacesWallpaperDarkPathField.stringValue = config.switcherWallpaperDarkPath
        switcherAllRecorder.hotkey = Hotkey.parse(config.switcherHotkeyAll)
        switcherAppRecorder.hotkey = Hotkey.parse(config.switcherHotkeyApp)
        switcherSpaceRecorder.hotkey = Hotkey.parse(config.switcherHotkeySpace)
        syncPermissions()
    }

    // MARK: - Actions

    private func syncSkhdManagementControls() {
        switcherSearchRecorder.isEnabled = config.manageSkhdConfig
        switcherSearchHint.stringValue = L10n.t("ui.keyboard.managementHint")
        switcherSearchHint.font = .systemFont(ofSize: 11)
        switcherSearchHint.preferredMaxLayoutWidth = 300
        switcherSearchHint.textColor = .secondaryLabelColor
        switcherSearchHint.isHidden = config.manageSkhdConfig
    }

    @objc private func changed() {
        config.style = stylePopup.indexOfSelectedItem == 1 ? .flag : .icon
        config.cellSize = sizeSlider.doubleValue.rounded()
        config.focusedAlpha = focusedSlider.doubleValue
        config.unfocusedAlpha = unfocusedSlider.doubleValue
        config.flagColor = flagWell.color.hexString
        config.showBackground = backgroundCheck.state == .on
        config.backgroundColor = backgroundWell.color.hexString
        config.confineToGap = confineCheck.state == .on
        config.autoPadding = autoPaddingCheck.state == .on
        config.indicatorClickThrough = clickThroughCheck.state == .on
        config.indicatorDragReorder = dragReorderCheck.state == .on
        dragReorderCheck.isEnabled = !config.indicatorClickThrough
        config.dockPreview = dockPreviewCheck.state == .on
        config.menuOpenOnHover = menuHoverCheck.state == .on
        let hyperSource = HyperSource.allCases[max(hyperSourcePopup.indexOfSelectedItem, 0)]
        config.hyperKey = hyperSource.rawValue
        let quickIdx = hyperQuickPopup.indexOfSelectedItem
        var quick = hyperQuickChoices.indices.contains(quickIdx) ? hyperQuickChoices[quickIdx] : .none
        if quick == .toggleCapsLock && hyperSource != .capsLock { quick = .none }
        config.hyperQuickPress = quick.rawValue
        config.hyperIncludeShift = hyperShiftCheck.state == .on
        let symbolChanged = config.hyperShowSymbol != (hyperSymbolCheck.state == .on)
        config.hyperShowSymbol = hyperSymbolCheck.state == .on
        syncHyperQuickChoices(source: hyperSource)
        hyperQuickPopup.isEnabled = hyperSource != .none
        hyperShiftCheck.isEnabled = hyperSource != .none
        syncHyperStatus(ax: permissionStatus?().0 ?? false)
        config.windowStrip = windowStripCheck.state == .on
        config.windowStripScale = (windowStripSizeSlider.doubleValue * 20).rounded() / 20
        windowStripSizeSlider.isEnabled = config.windowStrip
        config.fullWidthSide = fullWidthPopup.indexOfSelectedItem == 1 ? "right" : "left"
        // ms -> seconds, with sane floors
        config.debounceSeconds = max(0.0, Double(debounceField.integerValue) / 1000.0)
        config.pollSeconds = max(0.2, Double(pollField.integerValue) / 1000.0)
        config.yabaiPath = yabaiPathField.stringValue.trimmingCharacters(in: .whitespaces)
        config.switcherEnabled = switcherEnableCheck.state == .on
        let sIdx = switcherAppearancePopup.indexOfSelectedItem
        config.switcherAppearance = Self.switcherAppearanceOrder[
            (0..<Self.switcherAppearanceOrder.count).contains(sIdx) ? sIdx : 0]
        config.switcherHoldToCycle = switcherHoldCheck.state == .on
        config.switcherCaptureCmdTab = switcherCmdTabCheck.state == .on
        config.switcherFollowMove = spacesFocusDestinationCheck.state == .on
        config.switcherWallpaper = spacesWallpaperCheck.state == .on
        config.switcherWallpaperPath = spacesWallpaperPathField.stringValue
        config.switcherWallpaperDarkPath = spacesWallpaperDarkPathField.stringValue
        switcherCmdTabCheck.isEnabled = config.switcherEnabled && config.switcherHoldToCycle
        onChange(config)
        if symbolChanged {
            // Shortcut recorders render their text once; rebuild so ✦ shows up.
            let selected = tabView.flatMap { tv in tv.selectedTabViewItem.map { tv.indexOfTabViewItem($0) } } ?? 0
            buildContent()
            tabView?.selectTabViewItem(at: selected)
            syncControls()
        }
    }

    @objc private func loginChanged() {
        onLoginToggle(loginCheck.state == .on)
        loginCheck.state = loginIsEnabled() ? .on : .off
    }

    @objc private func languageChanged() {
        let idx = languagePopup.indexOfSelectedItem
        let lang = (idx >= 0 && idx < Self.languageOrder.count) ? Self.languageOrder[idx] : .auto
        config.language = lang.rawValue
        onChange(config)
        L10n.current = L10n.resolve(lang, preferred: Locale.preferredLanguages)

        let selectedTab = tabView.flatMap { tv -> Int? in
            guard let item = tv.selectedTabViewItem else { return nil }
            return tv.indexOfTabViewItem(item)
        } ?? 0
        buildContent()
        tabView?.selectTabViewItem(at: selectedTab)
        syncControls()
    }

    @objc private func grantAX() { onGrantAccessibility?() }
    @objc private func grantSR() { onGrantScreenRecording?() }

    @objc private func chooseWallpaper() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        spacesWallpaperPathField.stringValue = url.path
        changed()
    }

    @objc private func clearWallpaper() {
        spacesWallpaperPathField.stringValue = ""
        changed()
    }

    @objc private func chooseDarkWallpaper() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        spacesWallpaperDarkPathField.stringValue = url.path
        changed()
    }

    @objc private func clearDarkWallpaper() {
        spacesWallpaperDarkPathField.stringValue = ""
        changed()
    }
}

extension SettingsWindowController: NSTabViewDelegate {
    /// The Keyboard tab may have changed the search switcher binding.
    public func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard let engine = configEngine else { return }
        switcherSearchRecorder.hotkey = engine.loadBindingsOrDefault()
            .first { $0.actionID == "open-window-switcher" && $0.enabled }?.hotkey
    }
}
