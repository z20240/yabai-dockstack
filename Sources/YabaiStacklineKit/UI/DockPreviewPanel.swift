import AppKit
import CoreGraphics

public struct PreviewItem {
    public let windowID: Int
    public let title: String
    public let space: Int
    public let thumbnail: CGImage?
    public let icon: NSImage
    public init(windowID: Int, title: String, space: Int, thumbnail: CGImage?, icon: NSImage) {
        self.windowID = windowID; self.title = title; self.space = space
        self.thumbnail = thumbnail; self.icon = icon
    }
}

/// Floating popover shown above a hovered Dock icon, rendering an app's windows.
public final class DockPreviewPanel {
    private var panel: NSPanel?
    private var onClick: ((Int) -> Void)?
    /// The panel's current screen frame (Cocoa coords), for hit-testing keep-alive.
    public private(set) var currentFrame: CGRect?

    public init() {}
    public var isVisible: Bool { panel?.isVisible ?? false }

    public func show(items: [PreviewItem], aboveIcon iconFrame: CGRect, onClick: @escaping (Int) -> Void) {
        self.onClick = onClick
        let cellW: CGFloat = 200, cellH: CGFloat = 140, pad: CGFloat = 10, gap: CGFloat = 8
        let n = max(items.count, 1)
        let width = CGFloat(n) * cellW + CGFloat(n - 1) * gap + pad * 2
        let height = cellH + pad * 2

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

        let content = FlippedView(frame: CGRect(origin: .zero, size: frame.size))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        content.layer?.cornerRadius = 10
        for (i, item) in items.enumerated() {
            let cx = pad + CGFloat(i) * (cellW + gap)
            let cell = PreviewCell(frame: CGRect(x: cx, y: pad, width: cellW, height: cellH),
                                   item: item) { [weak self] id in self?.onClick?(id) }
            content.addSubview(cell)
        }
        p.contentView = content
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

    init(frame: NSRect, item: PreviewItem, onClick: @escaping (Int) -> Void) {
        self.windowID = item.windowID
        self.onClick = onClick
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        layer?.cornerRadius = 6

        let imgView = NSImageView(frame: NSRect(x: 6, y: 24, width: frame.width - 12, height: frame.height - 30))
        imgView.imageScaling = .scaleProportionallyUpOrDown
        if let t = item.thumbnail { imgView.image = NSImage(cgImage: t, size: .zero) }
        else { imgView.image = item.icon }
        addSubview(imgView)

        let label = NSTextField(labelWithString: "\(item.title)  ·  Space \(item.space)")
        label.font = .systemFont(ofSize: 11)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 6, y: 4, width: frame.width - 12, height: 16)
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) { onClick(windowID) }
}
