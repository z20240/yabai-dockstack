import AppKit

/// "Config file: <path> ⚠  [Choose…] Reset to auto  [Open in editor]" — the rc file
/// row shared by the yabai and Keyboard panes. Nothing here writes rc content:
/// Choose…/Reset only change dockstack's own path override (`sources.onPathChange`),
/// and Open only creates a missing (empty) file when `canCreateFile()` (allow mode).
/// It therefore stays enabled while the pane is read-only.
public final class RcFileRowView: NSView {

    private let tool: RcTool
    private let sources: RcSources
    private let canCreateFile: () -> Bool
    private let onStatus: (Bool, String) -> Void
    private var effectivePath = ""

    private let pathLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.lineBreakMode = .byTruncatingMiddle
        l.isSelectable = true
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return l
    }()
    private let warning: NSTextField = {
        let l = NSTextField(labelWithString: "⚠")
        l.textColor = .systemOrange
        l.isHidden = true
        return l
    }()
    private let chooseButton = NSButton()
    private let resetButton = NSButton()
    private let openButton = NSButton()

    /// Test seam: how the file is opened (default `open -t <path>`).
    var openFile: (String) -> Void = { path in
        // `open -t` uses the default GUI text editor instead of the file's default app,
        // which for dotfiles like ~/.yabairc is often a terminal editor.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-t", path]
        try? p.run()
    }

    var showsMismatchWarning: Bool { !warning.isHidden }
    var showsResetToAuto: Bool { !resetButton.isHidden }

    public init(tool: RcTool, sources: RcSources, canCreateFile: @escaping () -> Bool,
                onStatus: @escaping (Bool, String) -> Void) {
        self.tool = tool
        self.sources = sources
        self.canCreateFile = canCreateFile
        self.onStatus = onStatus
        super.init(frame: .zero)
        build()
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func build() {
        let label = NSTextField(labelWithString: L10n.t("ui.rc.label"))
        label.setContentHuggingPriority(.required, for: .horizontal)

        chooseButton.title = L10n.t("ui.rc.choose")
        chooseButton.bezelStyle = .rounded
        chooseButton.controlSize = .small
        chooseButton.target = self
        chooseButton.action = #selector(chooseTapped)

        resetButton.title = L10n.t("ui.rc.resetAuto")
        resetButton.isBordered = false
        resetButton.contentTintColor = .linkColor
        resetButton.controlSize = .small
        resetButton.target = self
        resetButton.action = #selector(resetTapped)

        openButton.title = L10n.t("ui.rc.open")
        openButton.bezelStyle = .rounded
        openButton.controlSize = .small
        openButton.target = self
        openButton.action = #selector(openTapped)

        for b in [chooseButton, resetButton, openButton] {
            b.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        let stack = NSStackView(views: [label, pathLabel, warning, chooseButton, resetButton, openButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private static func normalized(_ path: String) -> String {
        ((path as NSString).expandingTildeInPath as NSString).standardizingPath
    }

    /// Show `effectivePath`; "Reset to auto" only when an override is set; a ⚠ (hover
    /// text only) when it isn't the file the tool itself loads. No warning when the
    /// detected path is unknown ("").
    public func update(effectivePath: String) {
        self.effectivePath = effectivePath
        pathLabel.stringValue = (effectivePath as NSString).abbreviatingWithTildeInPath
        pathLabel.toolTip = effectivePath
        resetButton.isHidden = sources.pathOverride(tool).isEmpty
        let detected = sources.detectedPath(tool)
        let mismatch = !detected.isEmpty && !effectivePath.isEmpty
            && Self.normalized(detected) != Self.normalized(effectivePath)
        warning.isHidden = !mismatch
        warning.toolTip = mismatch
            ? String(format: L10n.t("ui.rc.mismatch"), (detected as NSString).abbreviatingWithTildeInPath)
            : nil
    }

    // MARK: - Actions

    @objc private func chooseTapped() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        if !effectivePath.isEmpty {
            let expanded = (effectivePath as NSString).expandingTildeInPath
            panel.directoryURL = URL(fileURLWithPath: (expanded as NSString).deletingLastPathComponent)
        }
        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.sources.onPathChange(self.tool, url.path)
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: handle) }
        else { handle(panel.runModal()) }
    }

    @objc private func resetTapped() {
        sources.onPathChange(tool, "")
    }

    @objc private func openTapped() {
        let path = (effectivePath as NSString).expandingTildeInPath
        guard !path.isEmpty else { return }
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            guard canCreateFile() else {
                onStatus(false, String(format: L10n.t("ui.rc.missing"),
                                       (path as NSString).abbreviatingWithTildeInPath))
                return
            }
            do {
                try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                       withIntermediateDirectories: true)
                guard fm.createFile(atPath: path, contents: Data()) else {
                    onStatus(false, String(format: L10n.t("ui.rc.missing"),
                                           (path as NSString).abbreviatingWithTildeInPath))
                    return
                }
            } catch {
                onStatus(false, error.localizedDescription)
                return
            }
        }
        openFile(path)
    }
}
