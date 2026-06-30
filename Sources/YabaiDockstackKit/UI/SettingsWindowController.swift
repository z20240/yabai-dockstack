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

    // controls
    private let stylePopup = NSPopUpButton()
    private let sizeSlider = NSSlider()
    private let focusedSlider = NSSlider()
    private let unfocusedSlider = NSSlider()
    private let flagWell = NSColorWell()
    private let backgroundCheck = NSButton(checkboxWithTitle: "Show background pill", target: nil, action: nil)
    private let backgroundWell = NSColorWell()
    private let confineCheck = NSButton(checkboxWithTitle: "Keep inside window gap (don't cover the app)", target: nil, action: nil)
    private let fullWidthPopup = NSPopUpButton()
    private let debounceField = NSTextField()
    private let pollField = NSTextField()
    private let yabaiPathField = NSTextField()
    private let dockPreviewCheck = NSButton(checkboxWithTitle: "Dock window previews (needs Accessibility + Screen Recording)", target: nil, action: nil)
    private let loginCheck = NSButton(checkboxWithTitle: "Start at login", target: nil, action: nil)
    // Permissions (for Dock previews)
    private let axStatus = NSTextField(labelWithString: "")
    private let axButton = NSButton(title: "Grant…", target: nil, action: nil)
    private let srStatus = NSTextField(labelWithString: "")
    private let srButton = NSButton(title: "Grant…", target: nil, action: nil)
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
        axStatus.stringValue = ax ? "✓ granted" : "✗ not granted"
        axStatus.textColor = ax ? .systemGreen : .systemRed
        axButton.isEnabled = !ax
        srStatus.stringValue = sr ? "✓ granted" : "✗ not granted"
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

    private func build() {
        NSColorPanel.shared.showsAlpha = true

        stylePopup.addItems(withTitles: ["Icon", "Flag"])
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

        fullWidthPopup.addItems(withTitles: ["Left", "Right"])
        fullWidthPopup.target = self; fullWidthPopup.action = #selector(changed)

        for f in [debounceField, pollField] {
            f.alignment = .right
            f.target = self; f.action = #selector(changed)
            f.widthAnchor.constraint(equalToConstant: 80).isActive = true
        }

        yabaiPathField.placeholderString = "auto-detect"
        yabaiPathField.target = self; yabaiPathField.action = #selector(changed)
        yabaiPathField.widthAnchor.constraint(equalToConstant: 240).isActive = true

        axButton.target = self; axButton.action = #selector(grantAX)
        srButton.target = self; srButton.action = #selector(grantSR)
        axButton.controlSize = .small; srButton.controlSize = .small
        let axCell = NSStackView(views: [axStatus, axButton]); axCell.spacing = 8
        let srCell = NSStackView(views: [srStatus, srButton]); srCell.spacing = 8

        let grid = NSGridView(views: [
            row("Accessibility:", axCell),
            row("Screen Recording:", srCell),
            row("Style:", stylePopup),
            row("Indicator size:", sizeSlider),
            row("Focused opacity:", focusedSlider),
            row("Unfocused opacity:", unfocusedSlider),
            row("Flag color:", flagWell),
            [NSGridCell.emptyContentView, backgroundCheck],
            row("Background color:", backgroundWell),
            [NSGridCell.emptyContentView, confineCheck],
            [NSGridCell.emptyContentView, dockPreviewCheck],
            row("Full-width side:", fullWidthPopup),
            row("Debounce (ms):", debounceField),
            row("Poll interval (ms):", pollField),
            row("yabai path:", yabaiPathField),
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
        let bannerLabel = NSTextField(wrappingLabelWithString:
            "⚠️  Dock window previews are off until you grant Accessibility + Screen Recording — use the Grant… buttons below.")
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
        appearanceItem.label = "Appearance"
        appearanceItem.view = appearancePane

        // --- yabai tab ---
        let yabaiItem = NSTabViewItem()
        yabaiItem.label = "yabai"
        if let engine = configEngine {
            yabaiItem.view = YabaiSettingsPaneView(engine: engine, rawFilePath: yabaiRawPath ?? "")
        } else {
            yabaiItem.view = makePlaceholder("yabai not configured")
        }

        // --- Keyboard tab ---
        let keyboardItem = NSTabViewItem()
        keyboardItem.label = "Keyboard"
        if let engine = configEngine {
            keyboardItem.view = ShortcutsPaneView(engine: engine, rawFilePath: skhdRawPath ?? "")
        } else {
            keyboardItem.view = makePlaceholder("Keyboard shortcuts not configured")
        }

        // --- NSTabView as the window's content view ---
        let tabView = NSTabView()
        tabView.addTabViewItem(appearanceItem)
        tabView.addTabViewItem(yabaiItem)
        tabView.addTabViewItem(keyboardItem)
        self.tabView = tabView

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                           styleMask: [.titled, .closable],
                           backing: .buffered, defer: false)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        win.title = "yabai-dockstack Settings" + (version.map { " (v\($0))" } ?? "")
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.contentView = tabView
        window = win
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

    @objc private func grantAX() { onGrantAccessibility?() }
    @objc private func grantSR() { onGrantScreenRecording?() }
}
