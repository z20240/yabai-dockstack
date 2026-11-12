import AppKit

/// A read-only "Title (N)" section with a disclosure triangle; its items (raw rc text)
/// are shown in a selectable monospaced list only when expanded. Collapsed by default,
/// hidden entirely when there are no items. Shared by the yabai ("Other rules") and
/// Keyboard ("Other shortcuts") panes.
public final class CollapsibleListView: NSView {

    private let titleKey: String
    private let disclosure = NSButton()
    private let titleButton = NSButton()
    private let body: NSTextField = {
        let f = NSTextField(wrappingLabelWithString: "")
        f.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        f.textColor = .secondaryLabelColor
        f.isSelectable = true
        return f
    }()

    public private(set) var isExpanded = false
    public private(set) var items: [String] = []

    /// The rendered heading, e.g. "Other rules (3)".
    public var title: String { titleButton.title }

    /// - Parameter titleKey: L10n key whose format takes the item count (`%d`).
    public init(titleKey: String) {
        self.titleKey = titleKey
        super.init(frame: .zero)
        build()
        setItems([])
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func build() {
        disclosure.bezelStyle = .disclosure
        disclosure.setButtonType(.pushOnPushOff)
        disclosure.title = ""
        disclosure.state = .off
        disclosure.target = self
        disclosure.action = #selector(toggleTapped)

        titleButton.isBordered = false
        titleButton.setButtonType(.momentaryChange)
        titleButton.font = .boldSystemFont(ofSize: 13)
        titleButton.target = self
        titleButton.action = #selector(toggleTapped)

        let header = NSStackView(views: [disclosure, titleButton])
        header.orientation = .horizontal
        header.spacing = 4

        body.isHidden = true
        let stack = NSStackView(views: [header, body])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            body.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    /// Replace the list. Hidden when empty; keeps the current expanded state.
    public func setItems(_ items: [String]) {
        self.items = items
        titleButton.title = String(format: L10n.t(titleKey), items.count)
        body.stringValue = items.joined(separator: "\n")
        isHidden = items.isEmpty
    }

    /// Expand or collapse the list.
    public func toggle() { setExpanded(!isExpanded) }

    public func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        disclosure.state = expanded ? .on : .off
        body.isHidden = !expanded
    }

    @objc private func toggleTapped(_ sender: NSButton) {
        // The disclosure button flips its own state before the action fires.
        if sender === disclosure { setExpanded(disclosure.state == .on) } else { toggle() }
    }
}
