import AppKit

/// One floating strip per display, directly under the menu bar (right-aligned):
/// every window on that display as icon + keyword chips, spaces separated by a
/// divider, empty spaces as small named slots. Click a chip to jump to it,
/// hover for the full title and space and a ✕ to close it; drag it onto any
/// display's strip to move it to that space.
public final class WindowStripController {
    private let client: YabaiClient
    private let focuser: WindowFocuser
    private var enabled = false
    private var panels: [Int: NSPanel] = [:]
    private var views: [Int: StripView] = [:]
    private var rendered: [Int: WindowStripModel.Rendered] = [:]
    /// The "+N" chip was clicked (wired to opening the window menu).
    public var onOverflowClick: (() -> Void)?
    /// A chip was dragged onto another space's section: (window id, space).
    public var onDropToSpace: ((Int, Int) -> Void)?
    /// A chip drag is in progress: refreshes wait (replacing the views would
    /// kill the drag) and re-render when it ends.
    private var dragging = false
    /// Size multiplier (Settings → window strip size); 1 = 24 pt tall.
    private var scale: CGFloat = 0.8
    private var last: (strips: [WindowStripModel.DisplayStrip], displays: [DisplayInfo])?

    static let baseHeight: CGFloat = 24

    public init(client: YabaiClient, focuser: WindowFocuser) {
        self.client = client
        self.focuser = focuser
    }

    public func setEnabled(_ on: Bool) {
        enabled = on
        if !on {
            DispatchQueue.main.async { [weak self] in self?.removeAll() }
        }
    }

    /// Off-main (refresh queue): queries spaces, builds the model, renders on main.
    public func update(windows: [YabaiWindow]) {
        guard enabled else { return }
        let strips = WindowStripModel.build(windows: windows, spaces: client.querySpacesInfo(),
                                            spaceLabels: client.querySpaceLabels(), includeEmpty: true)
        let displays = client.queryDisplaysInfo()
        DispatchQueue.main.async { [weak self] in self?.render(strips, displays: displays) }
    }

    /// Main thread. Redraws right away with the last data.
    public func setScale(_ s: Double) {
        let new = CGFloat(min(max(s, 0.5), 1.5))
        guard new != scale else { return }
        scale = new
        if let last { render(last.strips, displays: last.displays) }
    }

    private func removeAll() {
        StripTooltip.hide()
        dragging = false
        panels.values.forEach { $0.orderOut(nil) }
        panels.removeAll()
        views.removeAll()
        rendered.removeAll()
    }

    private func render(_ strips: [WindowStripModel.DisplayStrip], displays: [DisplayInfo]) {
        guard enabled else { return }
        last = (strips, displays)
        guard !dragging else { return }
        let screens = ScreenProvider.screens()
        var live = Set<Int>()
        for strip in strips where WindowStripModel.shows(strip) {
            guard let frame = displays.first(where: { $0.index == strip.display })?.frame,
                  let screen = screens.first(where: { abs($0.yabaiFrame.x - frame.x) < 1 && abs($0.yabaiFrame.y - frame.y) < 1 }),
                  let ns = NSScreen.screens.first(where: { $0.frame == screen.cocoaFrame }) else { continue }
            live.insert(strip.display)
            if panels[strip.display] != nil,
               !WindowStripModel.needsRender(cached: rendered[strip.display], strip: strip,
                                             frame: ns.visibleFrame, scale: Double(scale)) {
                continue
            }
            rendered[strip.display] = WindowStripModel.Rendered(strip: strip, frame: ns.visibleFrame,
                                                                scale: Double(scale))
            let panel = panels[strip.display] ?? makePanel()
            panels[strip.display] = panel
            let content = StripView(strip: strip, scale: scale, maxWidth: ns.visibleFrame.width / 2,
                                    onClick: { [weak self] id in
                                        DispatchQueue.global(qos: .userInitiated).async {
                                            self?.focuser.focus(windowId: id)
                                        }
                                    },
                                    onClose: { [weak self] id in
                                        DispatchQueue.global(qos: .userInitiated).async {
                                            self?.client.close(windowId: id)
                                        }
                                    },
                                    onOverflow: { [weak self] in self?.onOverflowClick?() })
            content.onDrag = { [weak self] id, space, phase in self?.handleDrag(id, from: space, phase) }
            views[strip.display] = content
            // The same material as the switcher, so it follows light / dark mode.
            let size = content.fittedSize
            let shell = RoundedPanelView(frame: CGRect(origin: .zero, size: size), radius: 7 * scale)
            let effect = NSVisualEffectView(frame: shell.bounds)
            effect.autoresizingMask = [.width, .height]
            effect.material = .hudWindow
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.addSubview(content)
            shell.addSubview(effect)
            // Size from the view's own fitted size (it doesn't follow the panel).
            let vf = ns.visibleFrame
            panel.setFrame(NSRect(x: vf.maxX - size.width - 8, y: vf.maxY - size.height - 2,
                                  width: size.width, height: size.height), display: true)
            panel.contentView = shell
            panel.orderFrontRegardless()
        }
        for (display, panel) in panels where !live.contains(display) {
            panel.contentView = nil  // detaches chips → their tooltip is dropped
            panel.orderOut(nil)
            panels.removeValue(forKey: display)
            views.removeValue(forKey: display)
            rendered.removeValue(forKey: display)
        }
    }

    /// Drags span every display's strip: the target is whichever strip the
    /// pointer is over, not only the one the chip came from.
    private func handleDrag(_ windowId: Int, from space: Int, _ phase: StripChip.DragPhase) {
        switch phase {
        case .began:
            dragging = true
            views.values.forEach { $0.setDragging(true) }
        case .moved:
            let target = dropTarget()
            views.values.forEach { $0.setTarget(target == space ? nil : target) }
        case .ended:
            let target = dropTarget()
            views.values.forEach { $0.setDragging(false) }
            if let target, target != space { onDropToSpace?(windowId, target) }
            dragging = false
            if let last {
                rendered.removeAll()  // force a redraw with whatever arrived meanwhile
                render(last.strips, displays: last.displays)
            }
        }
    }

    private func dropTarget() -> Int? {
        let p = NSEvent.mouseLocation
        return WindowStripModel.dropSpace(screenX: Double(p.x), screenY: Double(p.y),
                                          regions: views.values.compactMap(\.dropRegion))
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level = .floating
        p.isFloatingPanel = true
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        return p
    }
}

private extension NSView {
    /// A dynamic system color resolved for this view's light / dark
    /// appearance (layer colors don't follow appearance changes on their own).
    func resolved(_ color: NSColor) -> CGColor {
        var cg = color.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance { cg = color.cgColor }
        return cg
    }
}

/// The strip's content: chips separated by a thin divider between spaces;
/// empty spaces are small named slots (and drop targets).
private final class StripView: NSView {
    private struct Entry {
        let section: WindowStripModel.SpaceSection
        let chips: [StripChip]
        let slot: EmptySlot?
        let divider: NSView
        let highlight: NSView
    }
    private var entries: [Entry] = []
    private var overflow: OverflowChip?
    private var ranges: [(space: Int, minX: Double, maxX: Double)] = []
    /// A chip drag is in progress on some display: the visible space's tint
    /// gives way to the drop-target highlight.
    private var dragging = false
    private var target: Int?
    private let k: CGFloat
    /// Width × height the content needs (the panel is sized from this).
    private(set) var fittedSize: CGSize = .zero

    var onDrag: ((_ windowId: Int, _ space: Int, _ phase: StripChip.DragPhase) -> Void)?

    init(strip: WindowStripModel.DisplayStrip, scale k: CGFloat, maxWidth: CGFloat,
         onClick: @escaping (Int) -> Void, onClose: @escaping (Int) -> Void,
         onOverflow: @escaping () -> Void) {
        self.k = k
        super.init(frame: .zero)

        let chips = strip.sections.flatMap(\.chips)
        let dividers = CGFloat(max(strip.sections.count - 1, 0)) * 9 * k
        let slots = strip.sections.filter(\.chips.isEmpty).map { EmptySlot.width($0.name, scale: k) }.reduce(0, +)
        let density = WindowStripModel.fit(
            fullWidths: chips.map { Double(StripChip.width(for: $0, style: .full, scale: k)) },
            compactWidths: chips.map { Double(StripChip.width(for: $0, style: .compact, scale: k)) },
            iconWidth: Double(StripChip.width(for: nil, style: .iconOnly, scale: k)),
            overflowWidth: Double(30 * k), available: Double(maxWidth - dividers - slots - 8 * k))
        let style: StripChip.Style
        var budget = chips.count
        switch density {
        case .full: style = .full
        case .compact: style = .compact
        case .iconOnly: style = .iconOnly
        case let .overflow(n): style = .iconOnly; budget = n
        }

        for section in strip.sections {
            let highlight = NSView()
            highlight.wantsLayer = true
            highlight.layer?.cornerRadius = 5 * k
            addSubview(highlight)
            let divider = NSView()
            divider.wantsLayer = true
            addSubview(divider)
            var views: [StripChip] = []
            for chip in section.chips where budget > 0 {
                let v = StripChip(chip: chip, section: section, style: style, scale: k,
                                  onClick: onClick, onClose: onClose)
                v.onDrag = { [weak self] id, phase in self?.onDrag?(id, section.space, phase) }
                addSubview(v)
                views.append(v)
                budget -= 1
            }
            var slot: EmptySlot?
            if section.chips.isEmpty {
                let s = EmptySlot(name: section.name, scale: k)
                addSubview(s)
                slot = s
            }
            entries.append(Entry(section: section, chips: views, slot: slot,
                                 divider: divider, highlight: highlight))
        }
        if case let .overflow(n) = density {
            let more = OverflowChip(count: chips.count - n, scale: k, onClick: onOverflow)
            addSubview(more)
            overflow = more
        }
        relayout()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func relayout() {
        let h = WindowStripController.baseHeight * k
        let pad = 4 * k, dividerW = 9 * k
        var x = pad
        var shown = 0
        ranges = []
        for e in entries {
            // A space whose chips all went into the "+N" overflow takes no room.
            let visible = e.slot != nil || !e.chips.isEmpty
            e.divider.isHidden = !(visible && shown > 0)
            e.highlight.isHidden = !visible
            guard visible else { continue }
            if shown > 0 {
                e.divider.frame = NSRect(x: x + dividerW / 2, y: h * 0.22, width: 1, height: h * 0.56)
                x += dividerW
            }
            shown += 1
            let start = x
            for c in e.chips {
                c.frame.origin = CGPoint(x: x, y: 2 * k)
                x += c.frame.width
            }
            if let s = e.slot {
                s.frame.origin = CGPoint(x: x, y: 2 * k)
                x += s.frame.width
            }
            e.highlight.frame = NSRect(x: start - 2 * k, y: 2 * k, width: x - start + 4 * k, height: h - 4 * k)
            ranges.append((space: e.section.space, minX: Double(start), maxX: Double(x)))
        }
        if let more = overflow {
            more.frame = NSRect(x: x, y: 2 * k, width: 30 * k, height: h - 4 * k)
            x += 30 * k
        }
        fittedSize = CGSize(width: x + pad, height: h)
        frame = NSRect(origin: .zero, size: fittedSize)
        applyColors()
    }

    private func applyColors() {
        for e in entries {
            e.divider.layer?.backgroundColor = resolved(.separatorColor)
            if e.section.space == target {
                e.highlight.layer?.backgroundColor = resolved(NSColor.controlAccentColor.withAlphaComponent(0.45))
            } else if e.section.isVisible && !dragging {
                e.highlight.layer?.backgroundColor = resolved(NSColor.labelColor.withAlphaComponent(0.1))
            } else {
                e.highlight.layer?.backgroundColor = nil
            }
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    func setDragging(_ on: Bool) {
        dragging = on
        if !on { target = nil }
        applyColors()
    }

    func setTarget(_ space: Int?) {
        guard space != target else { return }
        target = space
        applyColors()
    }

    /// This strip on screen, for drops coming from any display's strip.
    var dropRegion: WindowStripModel.DropRegion? {
        guard let window else { return nil }
        return WindowStripModel.DropRegion(frame: window.convertToScreen(convert(bounds, to: nil)),
                                           sections: ranges)
    }
}

/// An empty space: a small tinted slot with the space's name.
private final class EmptySlot: NSView {
    private static let labelMax: CGFloat = 44

    private static func makeLabel(_ name: String, _ k: CGFloat) -> NSTextField {
        let l = NSTextField(labelWithString: name)
        l.font = .systemFont(ofSize: 10 * k, weight: .medium)
        l.textColor = .secondaryLabelColor
        l.alignment = .center
        l.lineBreakMode = .byTruncatingTail
        return l
    }

    /// Measured on a label set up exactly like the shown one (truncation
    /// changes its fitting width).
    private static func labelWidth(_ name: String, _ k: CGFloat) -> CGFloat {
        min(ceil(makeLabel(name, k).fittingSize.width), labelMax * k)
    }

    static func width(_ name: String, scale k: CGFloat) -> CGFloat {
        labelWidth(name, k) + 12 * k
    }

    init(name: String, scale k: CGFloat) {
        let h = (WindowStripController.baseHeight - 4) * k
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width(name, scale: k), height: h))
        wantsLayer = true
        layer?.cornerRadius = 4 * k
        let label = Self.makeLabel(name, k)
        let size = label.fittingSize
        label.frame = NSRect(x: 6 * k, y: (h - size.height) / 2,
                             width: Self.labelWidth(name, k), height: size.height)
        addSubview(label)
        applyColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func applyColors() {
        layer?.backgroundColor = resolved(NSColor.labelColor.withAlphaComponent(0.08))
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }
}

private final class StripChip: NSView {
    enum Style { case full, compact, iconOnly }
    private static let fullMax: CGFloat = 140
    private static let compactMax: CGFloat = 56
    private let chip: WindowStripModel.Chip
    private let section: WindowStripModel.SpaceSection
    private let onClick: (Int) -> Void
    private let onClose: (Int) -> Void
    private let iconView: NSImageView
    /// Hover ✕: takes the icon's place on a labelled chip (like a browser
    /// tab); a corner badge on an icon-only one, so the chip stays clickable.
    private let closeView = NSImageView()
    private let closeReplacesIcon: Bool

    private static func font(_ k: CGFloat) -> NSFont { .systemFont(ofSize: 11 * k) }

    static func width(for chip: WindowStripModel.Chip?, style: Style, scale k: CGFloat) -> CGFloat {
        let base = 5 * k + 16 * k + 5 * k
        guard style != .iconOnly, let chip else { return base }
        let cap = (style == .full ? fullMax : compactMax) * k
        return base + min(labelWidth(chip.keyword, k), cap) + 2 * k
    }

    /// Measured the way the label renders (NSString sizing misses the field's inset).
    private static func labelWidth(_ text: String, _ k: CGFloat) -> CGFloat {
        let f = NSTextField(labelWithString: text)
        f.font = font(k)
        return ceil(f.fittingSize.width)
    }

    init(chip: WindowStripModel.Chip, section: WindowStripModel.SpaceSection, style: Style,
         scale k: CGFloat, onClick: @escaping (Int) -> Void, onClose: @escaping (Int) -> Void) {
        self.chip = chip
        self.section = section
        self.onClick = onClick
        self.onClose = onClose
        closeReplacesIcon = style != .iconOnly
        let h = (WindowStripController.baseHeight - 4) * k
        let icon = 16 * k
        iconView = NSImageView(frame: NSRect(x: 5 * k, y: (h - icon) / 2, width: icon, height: icon))
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width(for: chip, style: style, scale: k), height: h))
        wantsLayer = true
        layer?.cornerRadius = 5 * k
        if chip.focused {
            layer?.borderWidth = 1.5
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        }
        iconView.image = NSRunningApplication(processIdentifier: pid_t(chip.pid))?.icon
            ?? NSWorkspace.shared.icon(for: .applicationBundle)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        closeView.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
        closeView.imageScaling = .scaleProportionallyUpOrDown
        closeView.contentTintColor = .secondaryLabelColor
        if closeReplacesIcon {
            closeView.frame = iconView.frame.insetBy(dx: 1 * k, dy: 1 * k)
        } else {
            let b = max(10, 10 * k)
            closeView.frame = NSRect(x: 0, y: h - b, width: b, height: b)
        }
        closeView.isHidden = true
        addSubview(closeView)

        guard style != .iconOnly else { return }
        let label = NSTextField(labelWithString: chip.keyword)
        label.font = Self.font(k)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.sizeToFit()
        let x = 5 * k + icon + 4 * k
        label.frame = NSRect(x: x, y: (h - label.frame.height) / 2,
                             width: frame.width - x - 1 * k, height: label.frame.height)
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self, userInfo: nil))
    }

    private func setHover(_ on: Bool) {
        layer?.backgroundColor = on ? resolved(NSColor.labelColor.withAlphaComponent(0.15)) : nil
        closeView.isHidden = !on
        if closeReplacesIcon { iconView.isHidden = on }
    }

    override func mouseEntered(with event: NSEvent) {
        setHover(true)
        let title = chip.title.isEmpty ? chip.app : "\(chip.app) — \(chip.title)"
        StripTooltip.show("\(title)\nSpace \(section.name)", below: self)
    }
    override func mouseExited(with event: NSEvent) {
        setHover(false)
        StripTooltip.hide(owner: self)
    }
    enum DragPhase { case began, moved, ended }
    var onDrag: ((_ windowId: Int, _ phase: DragPhase) -> Void)?
    private var pressPoint: NSPoint?
    private var dragging = false
    private var ghost: StripDragGhost?

    private func overClose(_ event: NSEvent) -> Bool {
        !closeView.isHidden && closeView.frame.contains(convert(event.locationInWindow, from: nil))
    }

    override func mouseDown(with event: NSEvent) {
        StripTooltip.hide(owner: self)
        pressPoint = event.locationInWindow
        dragging = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start = pressPoint else { return }
        let p = event.locationInWindow
        if !dragging {
            guard abs(p.x - start.x) + abs(p.y - start.y) > 4 else { return }
            dragging = true
            // The ✕ isn't part of what's being dragged.
            closeView.isHidden = true
            iconView.isHidden = false
            ghost = StripDragGhost(of: self, grabbedAt: convert(start, from: nil))
            alphaValue = 0.5
            onDrag?(chip.id, .began)
        }
        ghost?.follow(NSEvent.mouseLocation)
        onDrag?(chip.id, .moved)
    }
    override func mouseUp(with event: NSEvent) {
        guard pressPoint != nil else { return }
        pressPoint = nil
        if dragging {
            dragging = false
            ghost?.close()
            ghost = nil
            alphaValue = 1
            onDrag?(chip.id, .ended)
        } else if overClose(event) {
            alphaValue = 0.4  // until the refresh drops it
            onClose(chip.id)
        } else {
            onClick(chip.id)
        }
    }
    /// A refresh replaces the chips under a resting pointer: no mouseExited
    /// will ever come, so drop the tooltip when the chip leaves its window.
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            StripTooltip.hide(owner: self)
            ghost?.close()
            ghost = nil
        }
    }
}

/// A copy of the dragged chip that follows the pointer, across displays too,
/// so it's always clear what is being dragged and where it is.
private final class StripDragGhost {
    private let panel: NSPanel
    private let grab: NSPoint

    init(of chip: NSView, grabbedAt grab: NSPoint) {
        self.grab = grab
        let size = chip.bounds.size
        let image = NSImage(size: size)
        if let rep = chip.bitmapImageRepForCachingDisplay(in: chip.bounds) {
            chip.cacheDisplay(in: chip.bounds, to: rep)
            image.addRepresentation(rep)
        }
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let shell = RoundedPanelView(frame: NSRect(origin: .zero, size: size), radius: chip.layer?.cornerRadius ?? 5)
        let effect = NSVisualEffectView(frame: shell.bounds)
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        let iv = NSImageView(frame: shell.bounds)
        iv.image = image
        effect.addSubview(iv)
        shell.addSubview(effect)
        panel.contentView = shell
        panel.alphaValue = 0.9
        follow(NSEvent.mouseLocation)
        panel.orderFrontRegardless()
    }

    /// Keeps the point where the chip was grabbed under the pointer.
    func follow(_ mouse: NSPoint) {
        panel.setFrameOrigin(NSPoint(x: mouse.x - grab.x, y: mouse.y - grab.y))
    }

    func close() { panel.orderOut(nil) }
}

/// The strip's single tooltip (system tooltips don't show for an inactive
/// accessory app). One shared panel, so a missed mouseExited can't stack up
/// tooltips that never go away.
enum StripTooltip {
    private static var panel: NSPanel?
    private static weak var owner: NSView?

    static func show(_ text: String, below view: NSView) {
        hide()
        guard let win = view.window else { return }
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .white
        label.maximumNumberOfLines = 2
        label.sizeToFit()
        let pad: CGFloat = 6
        let size = NSSize(width: min(label.frame.width, 480) + pad * 2, height: label.frame.height + pad * 2)
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .floating
        p.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        p.isOpaque = false
        p.hasShadow = true
        p.ignoresMouseEvents = true
        label.frame = NSRect(x: pad, y: pad, width: size.width - pad * 2, height: label.frame.height)
        p.contentView?.addSubview(label)
        let origin = win.convertPoint(toScreen: view.convert(NSPoint(x: 0, y: 0), to: nil))
        var x = origin.x
        if let screen = win.screen { x = min(x, screen.visibleFrame.maxX - size.width - 4) }
        p.setFrameOrigin(NSPoint(x: x, y: origin.y - size.height - 6))
        p.orderFrontRegardless()
        panel = p
        owner = view
    }

    /// `owner`: only hide if that view is the one showing it (nil = always).
    static func hide(owner who: NSView? = nil) {
        if let who, owner !== who { return }
        panel?.orderOut(nil)
        panel = nil
        owner = nil
    }
}

private final class OverflowChip: NSView {
    private let onClick: () -> Void
    init(count: Int, scale k: CGFloat, onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: .zero)
        let label = NSTextField(labelWithString: "+\(count)")
        label.font = .systemFont(ofSize: 11 * k, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .center
        label.sizeToFit()
        label.frame = NSRect(x: 0, y: ((WindowStripController.baseHeight - 4) * k - label.frame.height) / 2,
                             width: 30 * k, height: label.frame.height)
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func mouseDown(with event: NSEvent) { onClick() }
}
