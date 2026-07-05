import AppKit

/// A simple preferences window so all appearance settings are adjustable from the
/// UI — no config-file editing. Changes apply live and persist via `onChange`.
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var tabView: NSTabView?

    /// Select a tab by index (0=Appearance, 1=yabai, 2=Keyboard). Builds the window first.
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
    private let fullWidthPopup = NSPopUpButton()
    private let debounceField = NSTextField()
    private let pollField = NSTextField()
    private let yabaiPathField = NSTextField()
    private let dockPreviewCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let loginCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
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
        dockPreviewCheck.target = self; dockPreviewCheck.action = #selector(changed)
        loginCheck.target = self; loginCheck.action = #selector(loginChanged)

        fullWidthPopup.target = self; fullWidthPopup.action = #selector(changed)

        for f in [debounceField, pollField] {
            f.alignment = .right
            f.target = self; f.action = #selector(changed)
            f.widthAnchor.constraint(equalToConstant: 80).isActive = true
        }

        yabaiPathField.target = self; yabaiPathField.action = #selector(changed)
        yabaiPathField.widthAnchor.constraint(equalToConstant: 240).isActive = true

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
        dockPreviewCheck.title = L10n.t("ui.appearance.dockPreview")
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
            [NSGridCell.emptyContentView, dockPreviewCheck],
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
            sizeSlider.widthAnchor.constraint(equalToConstant: 200),
        ])

        let appearanceItem = NSTabViewItem()
        appearanceItem.label = L10n.t("ui.tab.appearance")
        appearanceItem.view = appearancePane

        // --- yabai tab ---
        let yabaiItem = NSTabViewItem()
        yabaiItem.label = L10n.t("ui.tab.yabai")
        if let engine = configEngine {
            yabaiItem.view = YabaiSettingsPaneView(engine: engine, rawFilePath: yabaiRawPath ?? "")
        } else {
            yabaiItem.view = makePlaceholder(L10n.t("ui.yabai.notConfigured"))
        }

        // --- Keyboard tab ---
        let keyboardItem = NSTabViewItem()
        keyboardItem.label = L10n.t("ui.tab.keyboard")
        if let engine = configEngine {
            keyboardItem.view = ShortcutsPaneView(engine: engine, rawFilePath: skhdRawPath ?? "")
        } else {
            keyboardItem.view = makePlaceholder(L10n.t("ui.keyboard.notConfigured"))
        }

        // --- NSTabView as the window's content view ---
        let tabView = NSTabView()
        tabView.addTabViewItem(appearanceItem)
        tabView.addTabViewItem(yabaiItem)
        tabView.addTabViewItem(keyboardItem)
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
        dockPreviewCheck.state = config.dockPreview ? .on : .off
        fullWidthPopup.selectItem(at: config.fullWidthSide == "right" ? 1 : 0)
        debounceField.integerValue = Int((config.debounceSeconds * 1000).rounded())
        pollField.integerValue = Int((config.pollSeconds * 1000).rounded())
        yabaiPathField.stringValue = config.yabaiPath
        loginCheck.state = loginIsEnabled() ? .on : .off
        syncPermissions()
    }

    // MARK: - Actions

    @objc private func changed() {
        config.style = stylePopup.indexOfSelectedItem == 1 ? .flag : .icon
        config.cellSize = sizeSlider.doubleValue.rounded()
        config.focusedAlpha = focusedSlider.doubleValue
        config.unfocusedAlpha = unfocusedSlider.doubleValue
        config.flagColor = flagWell.color.hexString
        config.showBackground = backgroundCheck.state == .on
        config.backgroundColor = backgroundWell.color.hexString
        config.confineToGap = confineCheck.state == .on
        config.dockPreview = dockPreviewCheck.state == .on
        config.fullWidthSide = fullWidthPopup.indexOfSelectedItem == 1 ? "right" : "left"
        // ms -> seconds, with sane floors
        config.debounceSeconds = max(0.0, Double(debounceField.integerValue) / 1000.0)
        config.pollSeconds = max(0.2, Double(pollField.integerValue) / 1000.0)
        config.yabaiPath = yabaiPathField.stringValue.trimmingCharacters(in: .whitespaces)
        onChange(config)
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
}
