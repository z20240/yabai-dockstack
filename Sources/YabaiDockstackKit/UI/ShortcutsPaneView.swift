import AppKit

/// Keyboard Shortcuts pane: a Raycast-style grouped list of skhd bindings.
/// Each row has an enable checkbox, an action title, and a RecordHotkeyControl.
/// Bindings are looked up by actionID (never by row index) so the list can be
/// rebuilt without losing the in-memory state.
public final class ShortcutsPaneView: NSView {
    // MARK: - State

    private let engine: ConfigEngine
    private let rawFilePath: String
    private var bindings: [ShortcutBinding]

    // Per-actionID refs for cheap refreshConflicts() updates
    private var titleLabels: [String: NSTextField] = [:]
    private var checkboxes: [String: NSButton] = [:]

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

    public init(engine: ConfigEngine, rawFilePath: String) {
        self.engine = engine
        self.rawFilePath = rawFilePath
        self.bindings = engine.loadBindingsOrDefault()
        super.init(frame: .zero)
        buildUI()
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - UI Setup

    private func buildUI() {
        // Vertical stack that holds section headers + row views
        listStack = NSStackView()
        listStack.orientation = .vertical
        listStack.alignment = .left
        listStack.spacing = 4
        listStack.translatesAutoresizingMaskIntoConstraints = false

        // Document view for the scroll view
        let scrollContent = NSView()
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        scrollContent.addSubview(listStack)
        NSLayoutConstraint.activate([
            listStack.topAnchor.constraint(equalTo: scrollContent.topAnchor, constant: 8),
            listStack.leadingAnchor.constraint(equalTo: scrollContent.leadingAnchor, constant: 12),
            listStack.trailingAnchor.constraint(equalTo: scrollContent.trailingAnchor, constant: -12),
            listStack.bottomAnchor.constraint(equalTo: scrollContent.bottomAnchor, constant: -8),
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
        let applyButton = NSButton(title: "Apply", target: self, action: #selector(applyTapped))
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r"

        let editButton = NSButton(title: "⚙️ Edit raw file…", target: self, action: #selector(editRawTapped))
        editButton.bezelStyle = .rounded

        let resetButton = NSButton(title: "Reset to defaults", target: self, action: #selector(resetTapped))
        resetButton.bezelStyle = .rounded

        let bottomBar = NSStackView(views: [applyButton, editButton, resetButton, statusLabel])
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 8
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        addSubview(separator)
        addSubview(bottomBar)

        NSLayoutConstraint.activate([
            // Scroll view fills top portion
            scrollView.topAnchor.constraint(equalTo: topAnchor),
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
    }

    // MARK: - List Building

    /// Rebuild the entire grouped list from the current `bindings`.
    private func buildList() {
        // Tear down old rows
        for view in listStack.arrangedSubviews {
            listStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        titleLabels.removeAll()
        checkboxes.removeAll()

        let sections = ShortcutSections.build(bindings)
        for (sectionIndex, section) in sections.enumerated() {
            // Extra spacing before every section after the first
            if sectionIndex > 0, let prev = listStack.arrangedSubviews.last {
                listStack.setCustomSpacing(14, after: prev)
            }

            // Section header (bold, secondary color)
            let header = NSTextField(labelWithString: section.group.uppercased())
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

    /// Build one action row: [checkbox] [title label] [spacer] [RecordHotkeyControl].
    private func buildRowView(for row: ShortcutRow) -> NSView {
        let actionID = row.action.id

        // Enable / disable checkbox
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxChanged(_:)))
        checkbox.state = row.binding.enabled ? .on : .off
        checkbox.identifier = NSUserInterfaceItemIdentifier(actionID)
        checkboxes[actionID] = checkbox

        // Action title label
        let titleLabel = NSTextField(labelWithString: row.action.title)
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleLabels[actionID] = titleLabel

        // Flexible spacer that pushes the recorder to the trailing edge
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Hotkey recorder
        let recorder = RecordHotkeyControl(frame: .zero)
        recorder.hotkey = row.binding.hotkey
        recorder.onChange = { [weak self] newHotkey in
            guard let self else { return }
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

        let rowStack = NSStackView(views: [checkbox, titleLabel, spacer, recorder])
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
        guard let actionID = sender.identifier?.rawValue,
              let idx = bindings.firstIndex(where: { $0.actionID == actionID }) else { return }
        bindings[idx].enabled = sender.state == .on
        refreshConflicts()
    }

    @objc private func applyTapped() {
        do {
            try engine.saveSkhd(bindings)
            let r = engine.applySkhd()
            showStatus(r.ok, r.ok ? "Reloaded skhd" : r.output)
        } catch {
            showStatus(false, error.localizedDescription)
        }
    }

    @objc private func editRawTapped() {
        NSWorkspace.shared.open(URL(fileURLWithPath: rawFilePath))
    }

    @objc private func resetTapped() {
        bindings = DefaultTemplate.defaultBindings()
        buildList()
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
