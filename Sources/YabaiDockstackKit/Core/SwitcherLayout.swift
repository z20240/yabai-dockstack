import Foundation

/// Grid geometry for the switcher panel.
public struct SwitcherGrid: Equatable {
    public let columns: Int
    public let rows: Int
    public let cellWidth: Double
    public let cellHeight: Double

    public init(columns: Int, rows: Int, cellWidth: Double, cellHeight: Double) {
        self.columns = columns; self.rows = rows
        self.cellWidth = cellWidth; self.cellHeight = cellHeight
    }
}

public enum SwitcherLayout {
    /// Cell height for a given width: 16:10-ish image area + label strip.
    public static func cellHeight(width: Double, labelHeight: Double = 24) -> Double {
        (width * 0.625).rounded() + labelHeight
    }

    /// Pick a cell size that fits `count` cells within the available area,
    /// shrinking the cells (AltTab-style auto-size) and wrapping to more rows
    /// as the window count grows. Never returns more columns than cells.
    public static func grid(count: Int, maxWidth: Double, maxHeight: Double,
                            baseCellWidth: Double = 240, minCellWidth: Double = 128,
                            labelHeight: Double = 24, gap: Double = 10) -> SwitcherGrid {
        let n = max(count, 1)
        var w = baseCellWidth
        while true {
            let h = cellHeight(width: w, labelHeight: labelHeight)
            let cols = max(1, min(n, Int((maxWidth + gap) / (w + gap))))
            let rows = Int((Double(n) / Double(cols)).rounded(.up))
            let fits = Double(rows) * (h + gap) - gap <= maxHeight
            if fits || w - 16 < minCellWidth {
                return SwitcherGrid(columns: cols, rows: rows, cellWidth: w, cellHeight: h)
            }
            w -= 16
        }
    }
}
