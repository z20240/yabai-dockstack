import AppKit

/// A simple preferences window so all appearance settings are adjustable from the
/// UI — no config-file editing. Changes apply live and persist via `onChange`.
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
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
    private var permTimer: Timer?

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

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
                           styleMask: [.titled, .closable],
                           backing: .buffered, defer: false)
        win.title = "yabai-dockstack Settings"
        win.isReleasedWhenClosed = false
        win.delegate = self
        let content = NSView()
        content.addSubview(grid)
        win.contentView = content
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
            sizeSlider.widthAnchor.constraint(equalToConstant: 200),
        ])
        window = win
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
