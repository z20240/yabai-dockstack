import AppKit

/// Yabai config pane: default layout, paddings, gap, and a window-rules table.
/// Always shows what yabai is running now (`FaithfulYabai`: live state, falling back
/// to the rc file), with hover-only `!` badges where the file differs. Read-only unless
/// "Allow dockstack to edit yabairc" is on; then those values are the editable start.
public final class YabaiSettingsPaneView: NSView {

    // MARK: - State

    private let engine: ConfigEngine
    private let sources: RcSources
    private var settings: YabaiSettings
    /// The faithful values last loaded; edits are "unsaved" while they differ from it.
    private var baseline: YabaiSettings
    private var faithful: FaithfulYabaiView?
    private let onManagementChange: (Bool) -> Void
    private let managementCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let managementHint = NSTextField(wrappingLabelWithString: "")
    private var managedViews: [NSView] = []
    /// nil until the first updateManagementEnabled (from init).
    private var managementEnabled: Bool?
    private var rcRow: RcFileRowView!
    private let otherRulesList = CollapsibleListView(titleKey: "ui.yabai.otherRules")
    /// Shown whenever no transient status is (e.g. "yabai isn't running").
    private var persistentStatus = ""

    /// Asked before an Apply that comments out hand-written lines or adds the managed
    /// section for the first time. Test seam; defaults to the confirmation alert.
    lazy var confirm: (ApplyPlan, String) -> Bool = { [unowned self] plan, path in
        ApplyConfirmAlert.run(plan: plan, path: path, window: self.window)
    }

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

    /// Hover-only "!" next to each scalar field.
    private var fieldBadges: [YabaiField: NSTextField] = [:]

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

    public init(engine: ConfigEngine, sources: RcSources = .none,
                onManagementChange: @escaping (Bool) -> Void = { _ in }) {
        self.engine = engine
        self.sources = sources
        self.onManagementChange = onManagementChange
        self.settings = YabaiSettings.defaults
        self.baseline = YabaiSettings.defaults
        super.init(frame: .zero)
        buildUI()
        reload(force: true)
        updateManagementEnabled(engine.manageYabaiConfig)
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Build

    /// A small orange "!" whose explanation lives only in its tooltip.
    static func makeBadge() -> NSTextField {
        let b = NSTextField(labelWithString: "!")
        b.font = .boldSystemFont(ofSize: 13)
        b.textColor = .systemOrange
        b.isHidden = true
        b.setContentHuggingPriority(.required, for: .horizontal)
        return b
    }

    private func buildUI() {
        // rc file row: forwards path changes, then re-reads the (possibly new) file.
        var rowSources = sources
        let forward = sources.onPathChange
        rowSources.onPathChange = { [weak self] tool, path in
            forward(tool, path)
            self?.reload(force: true)
        }
        rcRow = RcFileRowView(tool: .yabai, sources: rowSources,
                              canCreateFile: { [weak self] in self?.engine.manageYabaiConfig ?? false },
                              onStatus: { [weak self] ok, msg in self?.showStatus(ok, msg) })

        managementCheck.title = L10n.t("ui.yabai.manageConfig")
        managementCheck.target = self
        managementCheck.action = #selector(managementChanged)
        managementHint.stringValue = L10n.t("ui.yabai.managementHint")
        managementHint.font = .systemFont(ofSize: 11)
        managementHint.textColor = .secondaryLabelColor
        let managementHeader = NSStackView(views: [rcRow, managementCheck, managementHint])
        managementHeader.orientation = .vertical
        managementHeader.alignment = .leading
        managementHeader.spacing = 6
        managementHeader.translatesAutoresizingMaskIntoConstraints = false
        managementHint.widthAnchor.constraint(equalTo: managementHeader.widthAnchor).isActive = true
        rcRow.widthAnchor.constraint(equalTo: managementHeader.widthAnchor).isActive = true
        // Integer text fields: right-aligned, fixed width
        for f in [topField, bottomField, leftField, rightField, gapField] {
            f.alignment = .right
            f.widthAnchor.constraint(equalToConstant: 80).isActive = true
        }
        // Fixed width so BSP/Float/Off render in full (not clipped to "…"). In a plain
        // row stack this constraint is honoured directly — unlike inside an NSGridView,
        // whose column (sized by the narrow 80pt number fields) compressed it.
        layoutControl.widthAnchor.constraint(equalToConstant: 200).isActive = true

        // Scalar form: a vertical stack of [right-aligned fixed-width label | control | !]
        // rows. Plain stacks keep each control at its own width, left-aligned, with no
        // NSGridView column-sizing quirks (which were squeezing the segmented control).
        let form = NSStackView(views: [
            formRow(L10n.t("ui.yabai.defaultLayout"), layoutControl, .layout),
            formRow(L10n.t("ui.yabai.topPadding"),    topField,      .top),
            formRow(L10n.t("ui.yabai.bottomPadding"), bottomField,   .bottom),
            formRow(L10n.t("ui.yabai.leftPadding"),   leftField,     .left),
            formRow(L10n.t("ui.yabai.rightPadding"),  rightField,    .right),
            formRow(L10n.t("ui.yabai.gap"),           gapField,      .gap),
        ])
        form.orientation = .vertical
        form.alignment   = .leading
        form.spacing     = 10
        form.translatesAutoresizingMaskIntoConstraints = false

        // Section header
        let rulesHeader = NSTextField(labelWithString: L10n.t("ui.yabai.windowRules"))
        rulesHeader.font = .boldSystemFont(ofSize: 13)

        // Table columns
        let appCol  = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appCol.title     = L10n.t("ui.yabai.colApp")
        appCol.minWidth  = 140
        appCol.width     = 200
        appCol.isEditable = true

        let modeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("mode"))
        modeCol.title    = L10n.t("ui.yabai.colMode")
        modeCol.minWidth = 90
        modeCol.width    = 150

        // Hover-only "!" for rules that differ between yabai and the file.
        let diffCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("diff"))
        diffCol.title    = ""
        diffCol.minWidth = 20
        diffCol.width    = 20
        diffCol.maxWidth = 20

        tableView = NSTableView()
        tableView.addTableColumn(appCol)
        tableView.addTableColumn(modeCol)
        tableView.addTableColumn(diffCol)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.rowHeight  = 24
        tableView.usesAlternatingRowBackgroundColors = true
        // The App column absorbs extra width (the "!" column stays narrow).
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
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
        let contentStack = NSStackView(views: [form, rulesHeader, tableScroll, ruleButtons, otherRulesList])
        contentStack.orientation = .vertical
        contentStack.alignment   = .leading
        contentStack.spacing     = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        otherRulesList.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

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
        let applyButton = NSButton(title: L10n.t("ui.apply"), target: self, action: #selector(applyTapped))
        applyButton.bezelStyle    = .rounded
        applyButton.keyEquivalent = "\r"

        let importButton = NSButton(title: L10n.t("ui.importExisting"), target: self, action: #selector(importTapped))
        importButton.bezelStyle = .rounded

        let resetButton = NSButton(title: L10n.t("ui.resetDefaults"), target: self, action: #selector(resetTapped))
        resetButton.bezelStyle = .rounded

        // Re-reads the file and yabai's live state; never writes, so always enabled.
        let reloadButton = NSButton(title: L10n.t("ui.rc.reload"), target: self, action: #selector(reloadTapped))
        reloadButton.bezelStyle = .rounded

        let bottomBar = NSStackView(views: [applyButton, importButton, resetButton, reloadButton, statusLabel])
        bottomBar.orientation = .horizontal
        bottomBar.spacing     = 8
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        addSubview(outerScroll)
        addSubview(managementHeader)
        addSubview(separator)
        addSubview(bottomBar)

        NSLayoutConstraint.activate([
            managementHeader.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            managementHeader.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            managementHeader.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            outerScroll.topAnchor.constraint(equalTo: managementHeader.bottomAnchor, constant: 8),
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
        // rc-backed editors only: the rc row, "Other rules" and Reload never write
        // the rc file, so they stay usable in read-only mode.
        managedViews = [form, tableScroll, ruleButtons, applyButton, importButton, resetButton]
    }

    /// Enable/disable editing. Turning it off discards unsaved edits and reloads the
    /// faithful view; turning it on keeps the shown values as the starting point.
    /// Never touches the rc file.
    public func updateManagementEnabled(_ enabled: Bool) {
        // Finish editing before disabling, including an active table field editor.
        if !enabled { window?.makeFirstResponder(nil) }
        let wasEnabled = managementEnabled
        managementEnabled = enabled
        engine.manageYabaiConfig = enabled
        managementCheck.state = enabled ? .on : .off
        managementHint.isHidden = enabled
        func update(_ view: NSView) {
            // Plain labels (form captions, "!" badges) keep their look and tooltips.
            if let label = view as? NSTextField, !label.isEditable { return }
            (view as? NSControl)?.isEnabled = enabled
            view.subviews.forEach(update)
        }
        managedViews.forEach(update)
        if wasEnabled == true && !enabled {
            reload(force: true)
        } else {
            refreshOtherRules()
            tableView.reloadData()
        }
    }

    @objc private func managementChanged() {
        let enabled = managementCheck.state == .on
        updateManagementEnabled(enabled)
        onManagementChange(enabled)
    }

    /// One form row: a fixed-width right-aligned label next to its control and its
    /// "!" badge, so all controls line up at the same x without NSGridView sizing.
    private func formRow(_ label: String, _ control: NSView, _ field: YabaiField) -> NSView {
        let l = NSTextField(labelWithString: label)
        l.alignment = .right
        l.widthAnchor.constraint(equalToConstant: 120).isActive = true
        l.setContentHuggingPriority(.required, for: .horizontal)
        let badge = Self.makeBadge()
        fieldBadges[field] = badge
        let s = NSStackView(views: [l, control, badge])
        s.orientation = .horizontal
        s.alignment   = .centerY
        s.spacing     = 8
        return s
    }

    // MARK: - Reload

    /// True when the controls hold values that differ from the last faithful load.
    public var hasUnsavedEdits: Bool { readFields(into: settings) != baseline }

    /// Re-read the rc file and yabai's live state and show them. With `force: false`
    /// this is skipped while there are unsaved edits. Never writes anything.
    public func reload(force: Bool) {
        if !force && hasUnsavedEdits { return }
        let view = FaithfulYabai.compose(live: sources.liveYabai(), file: engine.yabaiFileState(),
                                         autoPaddingOriginal: sources.autoPaddingOriginal())
        faithful = view
        settings = view.settings
        baseline = view.settings
        rcRow.update(effectivePath: engine.yabaiConfigPath)
        syncFields()
        updateBadges()
        refreshOtherRules()
        persistentStatus = view.liveAvailable ? "" : L10n.t("ui.yabai.notRunning")
        statusLabel.stringValue = persistentStatus
        statusLabel.textColor = .secondaryLabelColor
    }

    @objc private func reloadTapped() { reload(force: true) }

    /// "Other rules" is a read-only view of what can't be edited here; not-allow only.
    private func refreshOtherRules() {
        otherRulesList.setItems(faithful?.otherRules ?? [])
        if engine.manageYabaiConfig { otherRulesList.isHidden = true }
    }

    private static func layoutName(_ raw: String) -> String {
        switch raw {
        case YabaiSettings.Layout.bsp.rawValue:   return "BSP"
        case YabaiSettings.Layout.float.rawValue: return "Float"
        case YabaiSettings.Layout.off.rawValue:   return "Off"
        default: return raw
        }
    }

    private func updateBadges() {
        for (field, badge) in fieldBadges {
            guard let d = faithful?.fieldDiffs[field] else {
                badge.isHidden = true
                badge.toolTip = nil
                continue
            }
            let live = field == .layout ? Self.layoutName(d.live) : d.live
            let file = field == .layout ? Self.layoutName(d.file) : d.file
            var tip = String(format: L10n.t("ui.yabai.diff.field"), live, file)
            if d.autoPadding { tip += "\n" + L10n.t("ui.yabai.diff.autoPadding") }
            badge.toolTip = tip
            badge.isHidden = false
        }
        tableView.reloadData()
    }

    /// Tooltip for a rule row's "!", or nil when the rule matches the file.
    private func ruleDiffTip(app: String) -> String? {
        guard let diff = faithful?.ruleDiffs[app] else { return nil }
        switch diff {
        case .liveOnly: return L10n.t("ui.yabai.diff.liveOnly")
        case .fileOnly: return L10n.t("ui.yabai.diff.fileOnly")
        case .modeDiffers(let fileMode):
            let liveMode = faithful?.settings.rules.first { $0.app == app }?.mode ?? fileMode
            return String(format: L10n.t("ui.yabai.diff.modeDiffers"),
                          Self.modeName(liveMode), Self.modeName(fileMode))
        }
    }

    private static func modeName(_ mode: WindowRule.Mode) -> String {
        L10n.t(modes.first { $0.mode == mode }?.key ?? "ui.yabai.modeFloating")
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

    /// `base` with the scalar controls' current values.
    private func readFields(into base: YabaiSettings) -> YabaiSettings {
        var s = base
        switch layoutControl.selectedSegment {
        case 0: s.layout = .bsp
        case 1: s.layout = .float
        case 2: s.layout = .off
        default: break
        }
        s.topPadding    = max(0, topField.integerValue)
        s.bottomPadding = max(0, bottomField.integerValue)
        s.leftPadding   = max(0, leftField.integerValue)
        s.rightPadding  = max(0, rightField.integerValue)
        s.gap           = max(0, gapField.integerValue)
        return s
    }

    /// Read scalar UI controls into `settings` before saving.
    /// (NSTextField may not have fired its action if the user didn't press Enter.)
    private func flushFields() {
        settings = readFields(into: settings)
    }

    // MARK: - Rules table actions

    @objc private func addRule() {
        guard engine.manageYabaiConfig else { return }
        settings.rules.append(WindowRule(app: "NewApp", mode: .float))
        tableView.reloadData()
        let newRow = settings.rules.count - 1
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(newRow)
    }

    @objc private func removeRule() {
        guard engine.manageYabaiConfig else { return }
        let row = tableView.selectedRow
        guard row >= 0, row < settings.rules.count else { return }
        settings.rules.remove(at: row)
        tableView.reloadData()
    }

    // MARK: - Bottom bar actions

    @objc private func applyTapped() {
        guard engine.manageYabaiConfig else { return }
        // End any in-progress field editing before reading values
        window?.makeFirstResponder(nil)
        flushFields()
        // Commenting out hand-written lines (or adding the managed section for the
        // first time) needs the user's OK; cancelling writes nothing.
        let plan = engine.yabaiApplyPlan(settings)
        if plan.needsConfirmation && !confirm(plan, engine.yabaiConfigPath) { return }
        do {
            try engine.saveYabai(settings)
        } catch {
            showStatus(false, error.localizedDescription)
            return
        }
        baseline = settings
        let r = engine.applyYabai()
        if r.ok {
            // The file now holds exactly what yabai is restarting with.
            faithful?.fieldDiffs = [:]
            faithful?.ruleDiffs = [:]
            updateBadges()
        }
        showStatus(r.ok, r.ok ? L10n.t("ui.status.restartedYabai") : r.output)
    }

    @objc private func importTapped() {
        guard engine.manageYabaiConfig else { return }
        window?.makeFirstResponder(nil)
        flushFields()
        do {
            let (n, s) = try engine.importYabai(base: settings)
            settings = s
            syncFields()
            showStatus(true, n > 0 ? String(format: L10n.t("ui.status.importedSettings"), n) : L10n.t("ui.status.nothingToImport"))
        } catch {
            showStatus(false, error.localizedDescription)
        }
    }

    @objc private func resetTapped() {
        guard engine.manageYabaiConfig else { return }
        settings = DefaultTemplate.defaultYabaiSettings()
        syncFields()
        // Do NOT auto-apply
    }

    // MARK: - Status

    /// Display a transient status message (`success` picks the colour); afterwards the
    /// persistent status (e.g. "yabai isn't running") comes back.
    private func showStatus(_ success: Bool, _ message: String) {
        statusLabel.stringValue = message
        statusLabel.textColor   = success ? .systemGreen : .systemRed
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.statusLabel.stringValue == message else { return }
            self.statusLabel.stringValue = self.persistentStatus
            self.statusLabel.textColor = .secondaryLabelColor
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
            cell.isEnabled = engine.manageYabaiConfig
            return cell

        } else if colID == "mode" {
            let cellID = NSUserInterfaceItemIdentifier("modeCell")
            let cell: NSPopUpButton
            if let existing = tableView.makeView(withIdentifier: cellID, owner: self) as? NSPopUpButton {
                cell = existing
            } else {
                cell = NSPopUpButton()
                cell.identifier = cellID
                cell.addItems(withTitles: Self.modes.map { L10n.t($0.key) })
                cell.target = self
                cell.action = #selector(modeChanged(_:))
                cell.controlSize = .small
                cell.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            }
            cell.selectItem(at: Self.modes.firstIndex { $0.mode == rule.mode } ?? 0)
            cell.isEnabled = engine.manageYabaiConfig
            return cell

        } else if colID == "diff" {
            let cellID = NSUserInterfaceItemIdentifier("diffCell")
            let cell = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTextField
                ?? { let b = Self.makeBadge(); b.identifier = cellID; b.alignment = .center; return b }()
            let tip = ruleDiffTip(app: rule.app)
            cell.toolTip = tip
            cell.isHidden = tip == nil
            return cell
        }

        return nil
    }

    // MARK: Table cell actions

    @objc private func appNameChanged(_ sender: NSTextField) {
        guard engine.manageYabaiConfig else { return }
        let row = tableView.row(for: sender)
        guard row >= 0, row < settings.rules.count else { return }
        settings.rules[row].app = sender.stringValue
    }

    /// The Mode column's choices, in popup order.
    private static let modes: [(mode: WindowRule.Mode, key: String)] = [
        (.float, "ui.yabai.modeFloating"), (.manage, "ui.yabai.modeManage"), (.pin, "ui.yabai.modePin"),
    ]

    @objc private func modeChanged(_ sender: NSPopUpButton) {
        guard engine.manageYabaiConfig else { return }
        let row = tableView.row(for: sender)
        guard row >= 0, row < settings.rules.count else { return }
        guard Self.modes.indices.contains(sender.indexOfSelectedItem) else { return }
        settings.rules[row].mode = Self.modes[sender.indexOfSelectedItem].mode
    }
}

/// Flipped document view so a short content stack inside the scroll view aligns to
/// the TOP of the clip (an unflipped NSClipView pins a short document to the bottom,
/// which left a blank gap above the form).
private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}
