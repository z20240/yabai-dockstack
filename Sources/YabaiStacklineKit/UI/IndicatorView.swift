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
        // Cell size is the panel width: it may have been shrunk to fit a gap.
        let cell = bounds.width
        let flagColor = NSColor.fromHex(config.flagColor, fallback: .systemBlue)

        // Drop shadow so the indicator stands out over whatever window is behind it.
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 4

        // Backing pill: makes the indicator read as a deliberate floating chip
        // rather than icons pressed onto the app. It carries the shadow; the
        // cells are then drawn on top without their own shadow.
        if config.showBackground {
            NSGraphicsContext.saveGraphicsState()
            shadow.set()
            let bg = NSColor.fromHex(config.backgroundColor,
                                     fallback: NSColor(white: 0, alpha: 0.8))
            bg.setFill()
            let r = min(8, cell * 0.25)
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                         xRadius: r, yRadius: r).fill()
            NSGraphicsContext.restoreGraphicsState()
        } else {
            shadow.set()
        }

        for (i, win) in stack.windows.enumerated() {
            // top→bottom: index 0 at top
            let y = bounds.height - CGFloat(i + 1) * cell
            let rect = NSRect(x: 0, y: y, width: cell, height: cell)
            let alpha = win.hasFocus ? config.focusedAlpha : config.unfocusedAlpha
            switch config.style {
            case .icon:
                let inset = cell * 0.12
                icon(for: win).draw(in: rect.insetBy(dx: inset, dy: inset),
                                    from: .zero, operation: .sourceOver,
                                    fraction: CGFloat(alpha))
            case .flag:
                // slim vertical bar centered in the cell (taller than wide)
                let barWidth = cell * 0.28
                let barHeight = cell * 0.60
                let barRect = NSRect(x: (cell - barWidth) / 2,
                                     y: y + (cell - barHeight) / 2,
                                     width: barWidth,
                                     height: barHeight)
                let path = NSBezierPath(roundedRect: barRect,
                                        xRadius: barWidth / 2, yRadius: barWidth / 2)
                flagColor.withAlphaComponent(CGFloat(alpha)).setFill()
                path.fill()
            }
        }
    }

    // MARK: - Hit testing helpers

    private func cellIndexAt(_ pointInWindow: NSPoint) -> Int? {
        let p = convert(pointInWindow, from: nil)
        let cell = bounds.width
        let i = Int((bounds.height - p.y) / cell)
        return (i >= 0 && i < stack.windows.count) ? i : nil
    }

    // MARK: - Hover (M2)

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let cell = bounds.width
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
        let cell = bounds.width
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
