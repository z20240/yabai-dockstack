import AppKit

public final class IndicatorView: NSView {
    public var stack: Stack {
        didSet { needsDisplay = true; updateTrackingAreas() }
    }
    public var config: AppConfig {
        didSet { needsDisplay = true }
    }
    public var onClickWindow: ((Int) -> Void)?

    public init(stack: Stack, config: AppConfig) {
        self.stack = stack
        self.config = config
        super.init(frame: .zero)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    private func icon(for win: YabaiWindow) -> NSImage {
        if let app = NSRunningApplication(processIdentifier: pid_t(win.pid)), let i = app.icon {
            return i
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }

    public override func draw(_ dirtyRect: NSRect) {
        let cell = config.cellSize
        for (i, win) in stack.windows.enumerated() {
            // top→bottom: index 0 at top
            let y = bounds.height - CGFloat(i + 1) * cell
            let rect = NSRect(x: 0, y: y, width: cell, height: cell)
            let alpha = win.hasFocus ? config.focusedAlpha : config.unfocusedAlpha
            switch config.style {
            case .icon:
                icon(for: win).draw(in: rect.insetBy(dx: 3, dy: 3),
                                    from: .zero, operation: .sourceOver,
                                    fraction: CGFloat(alpha))
            case .flag:
                let path = NSBezierPath(roundedRect: rect.insetBy(dx: 4, dy: 4),
                                        xRadius: 3, yRadius: 3)
                NSColor.systemBlue.withAlphaComponent(CGFloat(alpha)).setFill()
                path.fill()
            }
        }
    }

    // MARK: - Hit testing helpers

    private func cellIndexAt(_ pointInWindow: NSPoint) -> Int? {
        let p = convert(pointInWindow, from: nil)
        let cell = config.cellSize
        let i = Int((bounds.height - p.y) / cell)
        return (i >= 0 && i < stack.windows.count) ? i : nil
    }

    // MARK: - Hover (M2)

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let cell = config.cellSize
        for (i, _) in stack.windows.enumerated() {
            let y = bounds.height - CGFloat(i + 1) * cell
            let rect = NSRect(x: 0, y: y, width: cell, height: cell)
            addTrackingArea(NSTrackingArea(
                rect: rect, options: [.mouseEnteredAndExited, .activeAlways],
                owner: self, userInfo: ["idx": i]))
        }
    }

    private var tooltip: NSPanel?

    public override func mouseEntered(with event: NSEvent) {
        let i = (event.trackingArea?.userInfo?["idx"] as? Int) ?? cellIndexAt(event.locationInWindow)
        guard let i, i < stack.windows.count else { return }
        showTooltip(text: stack.windows[i].title, cellIndex: i)
    }

    public override func mouseExited(with event: NSEvent) { hideTooltip() }

    private func showTooltip(text: String, cellIndex i: Int) {
        hideTooltip()
        guard let parent = window, !text.isEmpty else { return }
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .white
        label.sizeToFit()
        let pad: CGFloat = 6
        let size = NSSize(width: label.frame.width + pad * 2, height: label.frame.height + pad * 2)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        panel.isOpaque = false
        panel.hasShadow = true
        label.frame = NSRect(x: pad, y: pad, width: label.frame.width, height: label.frame.height)
        panel.contentView?.addSubview(label)
        // position to the right of the cell, in screen coords
        let cell = config.cellSize
        let cellY = bounds.height - CGFloat(i + 1) * cell
        let originInWindow = convert(NSPoint(x: bounds.width + 4, y: cellY), to: nil)
        let screenPoint = parent.convertPoint(toScreen: originInWindow)
        panel.setFrameOrigin(screenPoint)
        panel.orderFrontRegardless()
        tooltip = panel
    }

    private func hideTooltip() {
        tooltip?.orderOut(nil)
        tooltip = nil
    }

    // MARK: - Click (M2)

    public override func mouseDown(with event: NSEvent) {
        guard let i = cellIndexAt(event.locationInWindow) else { return }
        onClickWindow?(stack.windows[i].id)
    }
}
