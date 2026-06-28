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
                             edgeInset: Double = 0,
                             confineToGap: Bool = false,
                             minGapCell: Double = 8) -> IndicatorPlacement {
        let stackCenterX = stackFrame.x + stackFrame.w / 2
        let screenCenterX = screenFrame.x + screenFrame.w / 2

        // A near-full-width window has no clear left/right bias — use the
        // configured default side instead of the position heuristic.
        let nearFullWidth = stackFrame.w >= screenFrame.w * fullWidthThreshold
        let side: IndicatorSide = nearFullWidth
            ? fullWidthSide
            : (stackCenterX < screenCenterX ? .left : .right)

        let gap = side == .left
            ? stackFrame.x - screenFrame.x
            : (screenFrame.x + screenFrame.w) - (stackFrame.x + stackFrame.w)

        var cell = cellSize
        var x: Double

        if confineToGap && gap >= minGapCell {
            // Shrink to fit the gap and sit flush against the window's outer edge,
            // entirely inside the gap so the app is never covered.
            cell = Swift.min(cellSize, gap)
            x = side == .left ? stackFrame.x - cell : stackFrame.x + stackFrame.w
        } else {
            // Overlap fallback: place just outside the window, clamped on-screen.
            x = side == .left ? stackFrame.x - cell - offset
                              : stackFrame.x + stackFrame.w + offset
            let minX = screenFrame.x + edgeInset
            let maxX = screenFrame.x + screenFrame.w - cell - edgeInset
            x = Swift.min(Swift.max(x, minX), maxX)
        }

        let panel = YRect(x: x, y: stackFrame.y, w: cell, h: cell * Double(max(count, 1)))
        return IndicatorPlacement(panel: panel, side: side)
    }
}
