import AppKit
import CoreGraphics

public struct PreviewItem {
    public let windowID: Int
    public let title: String
    /// Short distinguishing label (e.g. project name); see `WindowLabeler`.
    public let keyword: String
    public let space: Int
    public let thumbnail: CGImage?
    public let icon: NSImage
    public init(windowID: Int, title: String, keyword: String, space: Int,
                thumbnail: CGImage?, icon: NSImage) {
        self.windowID = windowID; self.title = title; self.keyword = keyword; self.space = space
        self.thumbnail = thumbnail; self.icon = icon
    }
}

/// Floating popover shown above a hovered Dock icon, rendering an app's windows.
public final class DockPreviewPanel {
    private var panel: NSPanel?
    private var onClick: ((Int) -> Void)?
    private var onClose: ((Int) -> Void)?
    /// The panel's current screen frame (Cocoa coords), for hit-testing keep-alive.
    public private(set) var currentFrame: CGRect?

    public init() {}
    public var isVisible: Bool { panel?.isVisible ?? false }

    public func show(items: [PreviewItem], aboveIcon iconFrame: CGRect,
                     onClick: @escaping (Int) -> Void,
                     onClose: ((Int) -> Void)? = nil) {
        self.onClick = onClick
        self.onClose = onClose
        let cellW: CGFloat = 200, cellH: CGFloat = 140, gap: CGFloat = 8
        let n = max(items.count, 1)
        let cellAreaWidth = CGFloat(n) * cellW + CGFloat(n - 1) * gap
        let width = cellAreaWidth + 32
        let height = cellH + 32

        var x = iconFrame.midX - width / 2
        var y = iconFrame.maxY + 8
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(iconFrame) }) ?? NSScreen.main
        if let f = screen?.frame {
            x = min(max(x, f.minX + 4), f.maxX - width - 4)
            if y + height > f.maxY { y = iconFrame.minY - height - 8 }   // flip below if no room above
        }
        let frame = CGRect(x: x, y: y, width: width, height: height)

        let p = panel ?? makePanel()
        p.setFrame(frame, display: true)

        let content = FlippedView(frame: CGRect(x: 16, y: 16,
                                                width: cellAreaWidth, height: cellH))
        for (i, item) in items.enumerated() {
            let cx = CGFloat(i) * (cellW + gap)
            let cell = PreviewCell(frame: CGRect(x: cx, y: 0, width: cellW, height: cellH),
                                   item: item,
                                   onClick: { [weak self] id in self?.onClick?(id) },
                                   onClose: onClose == nil ? nil : { [weak self] id in self?.onClose?(id) })
            content.addSubview(cell)
        }
        let shell = RoundedPanelView(frame: CGRect(origin: .zero, size: frame.size), radius: 16)
        let effect = NSVisualEffectView(frame: shell.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.addSubview(content)
        shell.addSubview(effect)
        p.contentView = shell
        p.orderFrontRegardless()
        panel = p
        currentFrame = frame
    }

    public func hide() { panel?.orderOut(nil); currentFrame = nil }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        return p
    }
}

final class FlippedView: NSView { override var isFlipped: Bool { true } }

final class PreviewCell: NSView {
    private let windowID: Int
    private let onClick: (Int) -> Void
    private let onClose: ((Int) -> Void)?
    private let closeButton = NSButton()
    init(frame: NSRect, item: PreviewItem,
         onClick: @escaping (Int) -> Void, onClose: ((Int) -> Void)? = nil) {
        self.windowID = item.windowID
        self.onClick = onClick
        self.onClose = onClose
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 6
        applyAppearance()

        let imgView = NSImageView(frame: NSRect(x: 6, y: 24, width: frame.width - 12, height: frame.height - 30))
        imgView.imageScaling = .scaleProportionallyUpOrDown
        if let t = item.thumbnail { imgView.image = NSImage(cgImage: t, size: .zero) }
        else { imgView.image = item.icon }
        addSubview(imgView)

        let label = NSTextField(labelWithString: "\(item.keyword)  ·  Space \(item.space)")
        toolTip = item.title
        label.font = .systemFont(ofSize: 11)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 6, y: 4, width: frame.width - 12, height: 16)
        addSubview(label)

        // ✕ closes the window via yabai; revealed on hover (top-left, non-flipped coords).
        if onClose != nil {
            closeButton.bezelStyle = .circular
            closeButton.isBordered = false
            closeButton.title = ""
            closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill",
                                        accessibilityDescription: "Close window")
            closeButton.contentTintColor = .secondaryLabelColor
            closeButton.frame = NSRect(x: 5, y: frame.height - 23, width: 18, height: 18)
            closeButton.target = self
            closeButton.action = #selector(closeTapped)
            closeButton.isHidden = true
            addSubview(closeButton)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    private func applyAppearance() {
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
    }

    private func setHover(_ hovering: Bool) {
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(hovering ? 0.20 : 0.06).cgColor
        if onClose != nil { closeButton.isHidden = !hovering }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self, userInfo: nil))
        // If the cursor is already inside when the cell is (re)built, show hover.
        if let w = window, bounds.contains(convert(w.mouseLocationOutsideOfEventStream, from: nil)) {
            setHover(true)
        }
    }
    override func mouseEntered(with event: NSEvent) { setHover(true) }
    override func mouseExited(with event: NSEvent) { setHover(false) }
    override func mouseDown(with event: NSEvent) { onClick(windowID) }
    @objc private func closeTapped() { onClose?(windowID) }
}
