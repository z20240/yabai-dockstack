import AppKit

public final class IndicatorPanel: NSPanel {
    public let indicatorView: IndicatorView

    public init(stack: Stack, config: AppConfig, frame: CGRect) {
        self.indicatorView = IndicatorView(stack: stack, config: config)
        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        // Stay on the space where created (do NOT join all spaces), so a stack's
        // indicator only shows on the space the stack actually lives on. Panels are
        // recreated per space on space_changed, so they always land on the right one.
        collectionBehavior = [.ignoresCycle]
        indicatorView.frame = CGRect(origin: .zero, size: frame.size)
        contentView = indicatorView
        indicatorView.updateTrackingAreas()
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}
