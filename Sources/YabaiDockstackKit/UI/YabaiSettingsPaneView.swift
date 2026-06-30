import AppKit

/// Yabai config pane: default layout, paddings, gap, and a window-rules table.
/// Part of the Settings UI (Plan 2). UI-only; no unit tests.
public final class YabaiSettingsPaneView: NSView {

    // MARK: - State

    private let engine: ConfigEngine
    private let rawFilePath: String
    private var settings: YabaiSettings

    // MARK: - Scalar controls

    private let layoutControl: NSSegmentedControl = {
        let s = NSSegmentedControl(labels: ["BSP", "Float", "Off"],
                                   trackingMode: .selectOne,
                                   target: nil, action: nil)
        s.segmentDistribution = .fillEqually
        return s
    }()

    private let topField    = NSTextField()
    private let bottomField = NSTextField()
    private let leftField   = NSTextField()
    private let rightField  = NSTextField()
    private let gapField    = NSTextField()

    // MARK: - Rules table

    private var tableView: NSTableView!

    // MARK: - Status

    private let statusLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.textColor = .secondaryLabelColor
        l.font = .systemFont(ofSize: 11)
        l.isEditable = false
        l.isBordered = false
        l.drawsBackground = false
        l.lineBreakMode = .byTruncatingTail
        l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return l
    }()

    // MARK: - Init

    public init(engine: ConfigEngine, rawFilePath: String) {
        self.engine = engine
        self.rawFilePath = rawFilePath
        self.settings = engine.loadYabaiSettingsOrDefault()
        super.init(frame: .zero)
        buildUI()
        syncFields()
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Build

    private func buildUI() {
        // Integer text fields: right-aligned, fixed width
        for f in [topField, bottomField, leftField, rightField, gapField] {
            f.alignment = .right
            f.widthAnchor.constraint(equalToConstant: 80).isActive = true
        }
        // Fixed width so BSP/Float/Off render in full (not clipped to "…"). In a plain
        // row stack this constraint is honoured directly — unlike inside an NSGridView,
        // whose column (sized by the narrow 80pt number fields) compressed it.
        layoutControl.widthAnchor.constraint(equalToConstant: 200).isActive = true

        // Scalar form: a vertical stack of [right-aligned fixed-width label | control]
        // rows. Plain stacks keep each control at its own width, left-aligned, with no
        // NSGridView column-sizing quirks (which were squeezing the segmented control).
        let form = NSStackView(views: [
            formRow("Default layout:", layoutControl),
            formRow("Top padding:",    topField),
            formRow("Bottom padding:", bottomField),
            formRow("Left padding:",   leftField),
            formRow("Right padding:",  rightField),
            formRow("Gap:",            gapField),
        ])
        form.orientation = .vertical
        form.alignment   = .leading
        form.spacing     = 10
        form.translatesAutoresizingMaskIntoConstraints = false

        // Section header
        let rulesHeader = NSTextField(labelWithString: "Window Rules")
        rulesHeader.font = .boldSystemFont(ofSize: 13)

        // Table columns
        let appCol  = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appCol.title     = "App"
        appCol.minWidth  = 140
        appCol.width     = 200
        appCol.isEditable = true

        let modeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("mode"))
        modeCol.title    = "Mode"
        modeCol.minWidth = 90
        modeCol.width    = 110

        tableView = NSTableView()
        tableView.addTableColumn(appCol)
        tableView.addTableColumn(modeCol)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.rowHeight  = 24
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.allowsEmptySelection = true

        let tableScroll = NSScrollView()
        tableScroll.documentView    = tableView
        tableScroll.hasVerticalScroller = true
        tableScroll.autohidesScrollers  = true
        tableScroll.borderType          = .bezelBorder
        tableScroll.translatesAutoresizingMaskIntoConstraints = false
        tableScroll.heightAnchor.constraint(equalToConstant: 160).isActive = true

        // Add / Remove buttons
        let addButton = NSButton(title: "+", target: self, action: #selector(addRule))
        addButton.bezelStyle  = .smallSquare
        addButton.controlSize = .small

        let removeButton = NSButton(title: "–", target: self, action: #selector(removeRule))
        removeButton.bezelStyle  = .smallSquare
        removeButton.controlSize = .small

        let ruleButtons = NSStackView(views: [addButton, removeButton])
        ruleButtons.orientation = .horizontal
        ruleButtons.spacing     = 4

        // Content stack (scrolled)
        let contentStack = NSStackView(views: [form, rulesHeader, tableScroll, ruleButtons])
        contentStack.orientation = .vertical
        contentStack.alignment   = .leading
        contentStack.spacing     = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let scrollContent = FlippedDocumentView()
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        scrollContent.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollContent.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: scrollContent.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: scrollContent.trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: scrollContent.bottomAnchor, constant: -12),
        ])

        let outerScroll = NSScrollView()
        outerScroll.documentView    = scrollContent
        outerScroll.hasVerticalScroller = true
        outerScroll.autohidesScrollers  = true
        outerScroll.drawsBackground     = false
        outerScroll.translatesAutoresizingMaskIntoConstraints = false
        // Vertical scroll only — pin doc width to clip width
        scrollContent.widthAnchor.constraint(
            equalTo: outerScroll.contentView.widthAnchor).isActive = true
        // Table fills the content stack width
        tableScroll.widthAnchor.constraint(
            equalTo: contentStack.widthAnchor).isActive = true

        // Bottom bar
        let applyButton = NSButton(title: "Apply", target: self, action: #selector(applyTapped))
        applyButton.bezelStyle    = .rounded
        applyButton.keyEquivalent = "\r"

        let importButton = NSButton(title: "Import existing…", target: self, action: #selector(importTapped))
        importButton.bezelStyle = .rounded

        let editButton = NSButton(title: "⚙️ Edit raw file…", target: self, action: #selector(editRawTapped))
        editButton.bezelStyle = .rounded

        let resetButton = NSButton(title: "Reset to defaults", target: self, action: #selector(resetTapped))
        resetButton.bezelStyle = .rounded

        let bottomBar = NSStackView(views: [applyButton, importButton, editButton, resetButton, statusLabel])
        bottomBar.orientation = .horizontal
        bottomBar.spacing     = 8
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        addSubview(outerScroll)
        addSubview(separator)
        addSubview(bottomBar)

        NSLayoutConstraint.activate([
            outerScroll.topAnchor.constraint(equalTo: topAnchor),
            outerScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerScroll.trailingAnchor.constraint(equalTo: trailingAnchor),

            separator.topAnchor.constraint(equalTo: outerScroll.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),

            bottomBar.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 8),
            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    /// One form row: a fixed-width right-aligned label next to its control, so all
    /// controls line up at the same x without relying on NSGridView column sizing.
    private func formRow(_ label: String, _ control: NSView) -> NSView {
        let l = NSTextField(labelWithString: label)
        l.alignment = .right
        l.widthAnchor.constraint(equalToConstant: 120).isActive = true
        l.setContentHuggingPriority(.required, for: .horizontal)
        let s = NSStackView(views: [l, control])
        s.orientation = .horizontal
        s.alignment   = .centerY
        s.spacing     = 8
        return s
    }

    // MARK: - Sync

    /// Write `settings` values into all UI controls.
    private func syncFields() {
        switch settings.layout {
        case .bsp:   layoutControl.selectedSegment = 0
        case .float: layoutControl.selectedSegment = 1
        case .off:   layoutControl.selectedSegment = 2
        }
        topField.integerValue    = settings.topPadding
        bottomField.integerValue = settings.bottomPadding
        leftField.integerValue   = settings.leftPadding
        rightField.integerValue  = settings.rightPadding
        gapField.integerValue    = settings.gap
        tableView.reloadData()
    }

    /// Read scalar UI controls into `settings` before saving.
    /// (NSTextField may not have fired its action if the user didn't press Enter.)
    private func flushFields() {
        switch layoutControl.selectedSegment {
        case 0: settings.layout = .bsp
        case 1: settings.layout = .float
        case 2: settings.layout = .off
        default: break
        }
        settings.topPadding    = max(0, topField.integerValue)
        settings.bottomPadding = max(0, bottomField.integerValue)
        settings.leftPadding   = max(0, leftField.integerValue)
        settings.rightPadding  = max(0, rightField.integerValue)
        settings.gap           = max(0, gapField.integerValue)
    }

    // MARK: - Rules table actions

    @objc private func addRule() {
        settings.rules.append(WindowRule(app: "NewApp", mode: .float))
        tableView.reloadData()
        let newRow = settings.rules.count - 1
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(newRow)
    }

    @objc private func removeRule() {
        let row = tableView.selectedRow
        guard row >= 0, row < settings.rules.count else { return }
        settings.rules.remove(at: row)
        tableView.reloadData()
    }

    // MARK: - Bottom bar actions

    @objc private func applyTapped() {
        // End any in-progress field editing before reading values
        window?.makeFirstResponder(nil)
        flushFields()
        do {
            try engine.saveYabai(settings)
            let r = engine.applyYabai()
            showStatus(r.ok, r.ok ? "Restarted yabai" : r.output)
        } catch {
            showStatus(false, error.localizedDescription)
        }
    }

    @objc private func editRawTapped() {
        // `open -t` opens in the default GUI text editor (TextEdit, or whatever the
        // user set for the text role) instead of the file's default app — which for
        // dotfiles like ~/.yabairc is often a terminal editor.
        let path = (rawFilePath as NSString).expandingTildeInPath
        guard !path.isEmpty else { return }
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: Data(), attributes: nil)
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-t", path]
        try? p.run()
    }

    @objc private func importTapped() {
        do {
            let n = try engine.importYabai()
            settings = engine.loadYabaiSettingsOrDefault()
            syncFields()
            tableView.reloadData()
            showStatus(true, n > 0 ? "Imported \(n) setting(s) from ~/.yabairc" : "Nothing to import")
        } catch {
            showStatus(false, error.localizedDescription)
        }
    }

    @objc private func resetTapped() {
        settings = DefaultTemplate.defaultYabaiSettings()
        syncFields()
        // Do NOT auto-apply
    }

    // MARK: - Status

    /// Display a status message. `success` determines the label colour.
    private func showStatus(_ success: Bool, _ message: String) {
        statusLabel.stringValue = message
        statusLabel.textColor   = success ? .systemGreen : .systemRed
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.statusLabel.stringValue == message else { return }
            self.statusLabel.stringValue = ""
        }
    }
}

// MARK: - NSTableViewDataSource

extension YabaiSettingsPaneView: NSTableViewDataSource {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        settings.rules.count
    }
}

// MARK: - NSTableViewDelegate

extension YabaiSettingsPaneView: NSTableViewDelegate {

    public func tableView(_ tableView: NSTableView,
                          viewFor tableColumn: NSTableColumn?,
                          row: Int) -> NSView? {
        let rule = settings.rules[row]
        let colID = tableColumn?.identifier.rawValue

        if colID == "app" {
            let cellID = NSUserInterfaceItemIdentifier("appCell")
            let cell: NSTextField
            if let existing = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTextField {
                cell = existing
            } else {
                cell = NSTextField()
                cell.identifier              = cellID
                cell.isBordered              = false
                cell.drawsBackground         = false
                cell.isEditable      = true
                cell.target          = self
                cell.action                  = #selector(appNameChanged(_:))
            }
            cell.stringValue = rule.app
            return cell

        } else if colID == "mode" {
            let cellID = NSUserInterfaceItemIdentifier("modeCell")
            let cell: NSPopUpButton
            if let existing = tableView.makeView(withIdentifier: cellID, owner: self) as? NSPopUpButton {
                cell = existing
            } else {
                cell = NSPopUpButton()
                cell.identifier = cellID
                cell.addItems(withTitles: ["Floating", "Manage"])
                cell.target = self
                cell.action = #selector(modeChanged(_:))
                cell.controlSize = .small
                cell.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            }
            cell.selectItem(at: rule.mode == .float ? 0 : 1)
            return cell
        }

        return nil
    }

    // MARK: Table cell actions

    @objc private func appNameChanged(_ sender: NSTextField) {
        let row = tableView.row(for: sender)
        guard row >= 0, row < settings.rules.count else { return }
        settings.rules[row].app = sender.stringValue
    }

    @objc private func modeChanged(_ sender: NSPopUpButton) {
        let row = tableView.row(for: sender)
        guard row >= 0, row < settings.rules.count else { return }
        settings.rules[row].mode = sender.indexOfSelectedItem == 0 ? .float : .manage
    }
}

/// Flipped document view so a short content stack inside the scroll view aligns to
/// the TOP of the clip (an unflipped NSClipView pins a short document to the bottom,
/// which left a blank gap above the form).
private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}
