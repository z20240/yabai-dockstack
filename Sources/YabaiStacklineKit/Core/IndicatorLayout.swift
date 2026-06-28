public enum IndicatorSide { case left, right }

public struct IndicatorPlacement: Equatable {
    public let panel: YRect
    public let side: IndicatorSide
}

public enum IndicatorLayout {
    public static func place(stackFrame: YRect, screenFrame: YRect,
                             cellSize: Double, count: Int, offset: Double,
                             fullWidthSide: IndicatorSide = .left,
                             fullWidthThreshold: Double = 0.9,
                             edgeInset: Double = 0) -> IndicatorPlacement {
        let h = cellSize * Double(max(count, 1))
        let stackCenterX = stackFrame.x + stackFrame.w / 2
        let screenCenterX = screenFrame.x + screenFrame.w / 2

        // A near-full-width window has no clear left/right bias — use the
        // configured default side instead of the position heuristic.
        let nearFullWidth = stackFrame.w >= screenFrame.w * fullWidthThreshold
        let side: IndicatorSide = nearFullWidth
            ? fullWidthSide
            : (stackCenterX < screenCenterX ? .left : .right)

        var x: Double
        switch side {
        case .left:  x = stackFrame.x - cellSize - offset
        case .right: x = stackFrame.x + stackFrame.w + offset
        }
        let minX = screenFrame.x + edgeInset
        let maxX = screenFrame.x + screenFrame.w - cellSize - edgeInset
        x = Swift.min(Swift.max(x, minX), maxX)

        let panel = YRect(x: x, y: stackFrame.y, w: cellSize, h: h)
        return IndicatorPlacement(panel: panel, side: side)
    }
}
