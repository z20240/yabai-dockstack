import AppKit

/// Keyboard Shortcuts pane: a Raycast-style grouped list of skhd bindings.
/// Each row has an enable checkbox, an action title, and a RecordHotkeyControl.
/// Always shows what the skhdrc actually binds (`FaithfulSkhd`: catalog actions found
/// in the whole file, others unbound), plus a read-only "Other shortcuts (N)" list of
/// every line it can't represent. Read-only unless "Allow dockstack to edit skhdrc" is
/// on; then those bindings are the editable start. Bindings are looked up by actionID
/// (never by row index); the rows are built once and synced in place.
public final class ShortcutsPaneView: NSView {
    // MARK: - State

    private let engine: ConfigEngine
    private let sources: RcSources
    private var bindings: [ShortcutBinding] = []
    /// The faithful bindings last loaded; edits are "unsaved" while they differ from it.
    private var baseline: [ShortcutBinding] = []
    private var otherLines: [String] = []
    private let onManagementChange: (Bool) -> Void
    private let managementCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let managementHint = NSTextField(wrappingLabelWithString: "")
    private var managedViews: [NSView] = []
    /// nil until the first updateManagementEnabled (from init).
    private var managementEnabled: Bool?
    private var rcRow: RcFileRowView!
    private let otherShortcutsList = CollapsibleListView(titleKey: "ui.keyboard.otherShortcuts")

    // Per-actionID refs for in-place syncing and cheap refreshConflicts() updates
    private var titleLabels: [String: NSTextField] = [:]
    private var checkboxes: [String: NSButton] = [:]
    private var recorders: [String: RecordHotkeyControl] = [:]

    /// Asked before an Apply that comments out hand-written lines or adds the managed
    /// section for the first time. Test seam; defaults to the confirmation alert.
    lazy var confirm: (ApplyPlan, String) -> Bool = { [unowned self] plan, path in
        ApplyConfirmAlert.run(plan: plan, path: path, window: self.window)
    }

    // MARK: - Subviews

    private var listStack: NSStackView!

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
        self.onManagementChange = onManagementChange
        self.engine = engine
        self.sources = sources
        super.init(frame: .zero)
        buildUI()
        reload(force: true)
        updateManagementEnabled(engine.manageSkhdConfig)
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - UI Setup

    private func buildUI() {
        // rc file row: forwards path changes, then re-reads the (possibly new) file.
        var rowSources = sources
        let forward = sources.onPathChange
        rowSources.onPathChange = { [weak self] tool, path in
            forward(tool, path)
            self?.reload(force: true)
        }
        rcRow = RcFileRowView(tool: .skhd, sources: rowSources,
                              canCreateFile: { [weak self] in self?.engine.manageSkhdConfig ?? false },
                              onStatus: { [weak self] ok, msg in self?.showStatus(ok, msg) })

        managementCheck.title = L10n.t("ui.keyboard.manageConfig")
        managementCheck.target = self
        managementCheck.action = #selector(managementChanged)
        managementHint.stringValue = L10n.t("ui.keyboard.managementHint")
        managementHint.font = .systemFont(ofSize: 11)
        managementHint.textColor = .secondaryLabelColor
        let managementHeader = NSStackView(views: [rcRow, managementCheck, managementHint])
        managementHeader.orientation = .vertical
        managementHeader.alignment = .leading
        managementHeader.spacing = 6
        managementHeader.translatesAutoresizingMaskIntoConstraints = false
        managementHint.widthAnchor.constraint(equalTo: managementHeader.widthAnchor).isActive = true
        rcRow.widthAnchor.constraint(equalTo: managementHeader.widthAnchor).isActive = true
        // Vertical stack that holds section headers + row views
        listStack = NSStackView()
        listStack.orientation = .vertical
        listStack.alignment = .left
        listStack.spacing = 4
        listStack.translatesAutoresizingMaskIntoConstraints = false

        // The list, then the read-only "Other shortcuts" under it. Kept outside
        // listStack so disabling the rows doesn't disable its disclosure.
        let contentStack = NSStackView(views: [listStack, otherShortcutsList])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        listStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        otherShortcutsList.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        // Document view for the scroll view — flipped so the list opens at the
        // top (GENERAL) instead of scrolled to the bottom.
        let scrollContent = FlippedScrollContent()
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        scrollContent.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollContent.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: scrollContent.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: scrollContent.trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: scrollContent.bottomAnchor, constant: -8),
        ])

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = scrollContent
        // Pin document-view width to clip-view width — vertical scroll only
        scrollContent.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor).isActive = true

        // Populate the list
        buildList()

        // --- Bottom bar ---
        let applyButton = NSButton(title: L10n.t("ui.apply"), target: self, action: #selector(applyTapped))
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r"

        let importButton = NSButton(title: L10n.t("ui.importExisting"), target: self, action: #selector(importTapped))
        importButton.bezelStyle = .rounded

        let resetButton = NSButton(title: L10n.t("ui.resetDefaults"), target: self, action: #selector(resetTapped))
        resetButton.bezelStyle = .rounded

        // Re-reads the file; never writes, so always enabled.
        let reloadButton = NSButton(title: L10n.t("ui.rc.reload"), target: self, action: #selector(reloadTapped))
        reloadButton.bezelStyle = .rounded

        let bottomBar = NSStackView(views: [applyButton, importButton, resetButton, reloadButton, statusLabel])
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 8
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        addSubview(managementHeader)
        addSubview(scrollView)
        addSubview(separator)
        addSubview(bottomBar)

        NSLayoutConstraint.activate([
            // Scroll view fills top portion
            managementHeader.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            managementHeader.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            managementHeader.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: managementHeader.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            // Separator between scroll area and button bar
            separator.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            // Bottom bar
            bottomBar.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 8),
            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
        // rc-backed editors only: the rc row, "Other shortcuts" and Reload never
        // write the rc file, so they stay usable in read-only mode.
        managedViews = [listStack, applyButton, importButton, resetButton]
    }

    /// Enable/disable editing. Turning it off discards unsaved edits and reloads the
    /// faithful view; turning it on keeps the shown bindings as the starting point.
    /// Never touches the rc file.
    public func updateManagementEnabled(_ enabled: Bool) {
        // Stop active editing and shortcut recording when management is disabled.
        if !enabled { window?.makeFirstResponder(nil) }
        let wasEnabled = managementEnabled
        managementEnabled = enabled
        engine.manageSkhdConfig = enabled
        managementCheck.state = enabled ? .on : .off
        managementHint.isHidden = enabled
        func update(_ view: NSView) {
            // Plain labels (titles, section headers) keep their look and conflict colour.
            if let label = view as? NSTextField, !label.isEditable { return }
            (view as? RecordHotkeyControl)?.isEnabled = enabled
            (view as? NSControl)?.isEnabled = enabled
            view.subviews.forEach(update)
        }
        managedViews.forEach(update)
        if wasEnabled == true && !enabled {
            reload(force: true)
        } else {
            refreshOtherShortcuts()
        }
    }

    @objc private func managementChanged() {
        let enabled = managementCheck.state == .on
        updateManagementEnabled(enabled)
        onManagementChange(enabled)
    }

    // MARK: - Reload

    /// True when the rows hold bindings that differ from the last faithful load.
    public var hasUnsavedEdits: Bool { bindings != baseline }

    /// Re-read the skhdrc and show its bindings. With `force: false` this is skipped
    /// while there are unsaved edits. Never writes anything.
    public func reload(force: Bool) {
        if !force && hasUnsavedEdits { return }
        let view = engine.faithfulSkhd()
        bindings = view.bindings
        baseline = view.bindings
        otherLines = view.others
        rcRow.update(effectivePath: engine.skhdConfigPath)
        syncRows()
        refreshOtherShortcuts()
    }

    @objc private func reloadTapped() { reload(force: true) }

    /// Set one action's hotkey (nil unbinds it) without touching the other rows'
    /// unsaved edits. Contract: the caller must ALREADY have written this value to the
    /// skhdrc (e.g. the Switcher tab's search hotkey after its own save) — the row's
    /// saved baseline moves with it, so this alone never counts as an unsaved edit.
    public func setBinding(actionID: String, hotkey: Hotkey?) {
        bindings = ShortcutBindings.setting(bindings, action: actionID, hotkey: hotkey)
        baseline = ShortcutBindings.setting(baseline, action: actionID, hotkey: hotkey)
        syncRows()
    }

    /// "Other shortcuts" is a read-only view of what can't be edited here; not-allow only.
    private func refreshOtherShortcuts() {
        otherShortcutsList.setItems(otherLines)
        if engine.manageSkhdConfig { otherShortcutsList.isHidden = true }
    }

    /// Push `bindings` into the existing rows' checkboxes and recorders.
    private func syncRows() {
        for (actionID, recorder) in recorders {
            let b = bindings.first { $0.actionID == actionID }
            recorder.hotkey = b?.hotkey
            checkboxes[actionID]?.state = b?.enabled == true ? .on : .off
        }
        refreshConflicts()
    }

    // MARK: - List Building

    /// Build the grouped list (one row per catalog action) from the current `bindings`.
    private func buildList() {
        // Tear down old rows
        for view in listStack.arrangedSubviews {
            listStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        titleLabels.removeAll()
        checkboxes.removeAll()
        recorders.removeAll()

        let sections = ShortcutSections.build(bindings)
        for (sectionIndex, section) in sections.enumerated() {
            // Extra spacing before every section after the first
            if sectionIndex > 0, let prev = listStack.arrangedSubviews.last {
                listStack.setCustomSpacing(14, after: prev)
            }

            // Section header (bold, secondary color)
            let header = NSTextField(labelWithString: L10n.t("group.\(section.group)").uppercased())
            header.font = .boldSystemFont(ofSize: 10)
            header.textColor = .secondaryLabelColor
            listStack.addArrangedSubview(header)
            listStack.setCustomSpacing(6, after: header)

            for row in section.rows {
                let rowView = buildRowView(for: row)
                listStack.addArrangedSubview(rowView)
                // Stretch each row to fill the stack's width
                rowView.widthAnchor.constraint(equalTo: listStack.widthAnchor).isActive = true
            }
        }

        refreshConflicts()
    }

    /// Build one action row: [checkbox] [icon] [title label] [spacer] [RecordHotkeyControl].
    private func buildRowView(for row: ShortcutRow) -> NSView {
        let actionID = row.action.id

        // Enable / disable checkbox
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxChanged(_:)))
        checkbox.isEnabled = engine.manageSkhdConfig
        checkbox.state = row.binding.enabled ? .on : .off
        checkbox.identifier = NSUserInterfaceItemIdentifier(actionID)
        checkboxes[actionID] = checkbox

        // Small monochrome SF Symbol; template rendering follows light/dark.
        let icon = NSImageView()
        if let img = NSImage(systemSymbolName: row.action.symbol, accessibilityDescription: nil) {
            img.isTemplate = true
            icon.image = img
            icon.contentTintColor = .secondaryLabelColor
        }
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 18).isActive = true

        // Action title label
        let titleLabel = NSTextField(labelWithString: L10n.t("action.\(row.action.id)"))
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleLabels[actionID] = titleLabel

        // Flexible spacer that pushes the recorder to the trailing edge
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Hotkey recorder
        let recorder = RecordHotkeyControl(frame: .zero)
        recorder.isEnabled = engine.manageSkhdConfig
        recorder.hotkey = row.binding.hotkey
        recorder.identifier = NSUserInterfaceItemIdentifier(actionID)
        recorders[actionID] = recorder
        recorder.onChange = { [weak self] newHotkey in
            guard let self, self.engine.manageSkhdConfig else { return }
            guard let idx = self.bindings.firstIndex(where: { $0.actionID == actionID }) else { return }
            self.bindings[idx].hotkey = newHotkey
            if newHotkey != nil {
                // Enabling when a hotkey is set
                self.bindings[idx].enabled = true
                self.checkboxes[actionID]?.state = .on
            } else {
                // Clearing the hotkey also disables the row
                self.bindings[idx].enabled = false
                self.checkboxes[actionID]?.state = .off
            }
            self.refreshConflicts()
        }

        let rowStack = NSStackView(views: [checkbox, icon, titleLabel, spacer, recorder])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        return rowStack
    }

    // MARK: - Conflict Refresh

    /// Recompute conflicts and red-tint any title labels for conflicting action IDs.
    private func refreshConflicts() {
        let conflicting = ShortcutSections.conflictingActionIDs(bindings)
        for (actionID, label) in titleLabels {
            label.textColor = conflicting.contains(actionID) ? .systemRed : .labelColor
        }
    }

    // MARK: - Bottom Bar Actions

    @objc private func checkboxChanged(_ sender: NSButton) {
        guard engine.manageSkhdConfig else { return }
        guard let actionID = sender.identifier?.rawValue,
              let idx = bindings.firstIndex(where: { $0.actionID == actionID }) else { return }
        bindings[idx].enabled = sender.state == .on
        refreshConflicts()
    }

    @objc private func applyTapped() {
        guard engine.manageSkhdConfig else { return }
        window?.makeFirstResponder(nil)
        // Commenting out hand-written lines (or adding the managed section for the
        // first time) needs the user's OK; cancelling writes nothing.
        // A file Apply would refuse (malformed markers, unreadable) is reported before
        // any dialog, and nothing is written.
        let plan: ApplyPlan
        do { plan = try engine.skhdApplyPlan(bindings) } catch {
            showStatus(false, error.localizedDescription)
            return
        }
        if plan.needsConfirmation && !confirm(plan, engine.skhdConfigPath) { return }
        do {
            try engine.saveSkhd(bindings)
        } catch {
            showStatus(false, error.localizedDescription)
            return
        }
        baseline = bindings
        let r = engine.applySkhd()
        showStatus(r.ok, r.ok ? L10n.t("ui.status.reloadedSkhd") : r.output)
    }

    @objc private func importTapped() {
        guard engine.manageSkhdConfig else { return }
        window?.makeFirstResponder(nil)
        do {
            let (n, b) = try engine.importSkhd(base: bindings)
            // The file's managed section now holds exactly these bindings.
            bindings = b
            baseline = b
            syncRows()
            showStatus(true, n > 0 ? String(format: L10n.t("ui.status.importedBindings"), n) : L10n.t("ui.status.nothingToImport"))
        } catch {
            showStatus(false, error.localizedDescription)
        }
    }

    @objc private func resetTapped() {
        guard engine.manageSkhdConfig else { return }
        bindings = DefaultTemplate.defaultBindings()
        syncRows()
        // Do NOT auto-apply — user must press Apply
    }

    // MARK: - Status Display

    private func showStatus(_ ok: Bool, _ message: String) {
        statusLabel.stringValue = message
        statusLabel.textColor = ok ? .systemGreen : .systemRed
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.statusLabel.stringValue == message else { return }
            self.statusLabel.stringValue = ""
        }
    }
}

/// Flipped so short/long content anchors to the top of the scroll view.
private final class FlippedScrollContent: NSView {
    override var isFlipped: Bool { true }
}
