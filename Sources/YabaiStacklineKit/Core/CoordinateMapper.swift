import CoreGraphics

public enum CoordinateMapper {
    public static func toCocoa(_ rect: YRect, primaryHeight: Double) -> CGRect {
        let y = primaryHeight - rect.y - rect.h
        return CGRect(x: rect.x, y: y, width: rect.w, height: rect.h)
    }
}
