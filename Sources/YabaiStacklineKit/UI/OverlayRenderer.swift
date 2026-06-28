import AppKit

public final class OverlayRenderer {
    private var config: AppConfig
    private var panels: [String: IndicatorPanel] = [:]
    public var onClickWindow: ((Int) -> Void)?

    public init(config: AppConfig) { self.config = config }

    public func updateConfig(_ config: AppConfig) {
        self.config = config
        for panel in panels.values {
            panel.indicatorView.config = config
        }
    }

    public func update(_ stacks: [Stack]) {
        let screens = ScreenProvider.screens()
        let primaryH = ScreenProvider.primaryHeight()
        var liveKeys = Set<String>()

        for stack in stacks {
            liveKeys.insert(stack.key)
            // find the screen whose yabai frame contains the stack center
            let cx = stack.frame.x + stack.frame.w / 2
            let cy = stack.frame.y + stack.frame.h / 2
            let screen = screens.first {
                cx >= $0.yabaiFrame.x && cx < $0.yabaiFrame.x + $0.yabaiFrame.w &&
                cy >= $0.yabaiFrame.y && cy < $0.yabaiFrame.y + $0.yabaiFrame.h
            } ?? screens.first
            guard let screen else { continue }

            let placement = IndicatorLayout.place(
                stackFrame: stack.frame, screenFrame: screen.yabaiFrame,
                cellSize: config.cellSize, count: stack.windows.count, offset: config.offset)
            let cocoa = CoordinateMapper.toCocoa(placement.panel, primaryHeight: primaryH)

            if let panel = panels[stack.key] {
                panel.setFrame(cocoa, display: true)
                panel.indicatorView.frame = CGRect(origin: .zero, size: cocoa.size)
                panel.indicatorView.config = config
                panel.indicatorView.stack = stack
            } else {
                let panel = IndicatorPanel(stack: stack, config: config, frame: cocoa)
                panel.indicatorView.onClickWindow = { [weak self] id in self?.onClickWindow?(id) }
                panel.orderFrontRegardless()
                panels[stack.key] = panel
            }
        }

        // remove stale panels
        for (key, panel) in panels where !liveKeys.contains(key) {
            panel.orderOut(nil)
            panels.removeValue(forKey: key)
        }
    }
}
