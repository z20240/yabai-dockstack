import Foundation

public struct WindowRule: Equatable {
    public enum Mode: String { case float, manage }   // float => manage=off; manage => manage=on
    public var app: String
    public var mode: Mode
    public init(app: String, mode: Mode) { self.app = app; self.mode = mode }
}

public struct YabaiSettings: Equatable {
    public enum Layout: String { case bsp, float, off }
    public var layout: Layout
    public var topPadding: Int
    public var bottomPadding: Int
    public var leftPadding: Int
    public var rightPadding: Int
    public var gap: Int
    public var rules: [WindowRule]

    public init(layout: Layout, topPadding: Int, bottomPadding: Int,
                leftPadding: Int, rightPadding: Int, gap: Int, rules: [WindowRule]) {
        self.layout = layout; self.topPadding = topPadding; self.bottomPadding = bottomPadding
        self.leftPadding = leftPadding; self.rightPadding = rightPadding; self.gap = gap; self.rules = rules
    }

    public static let defaults = YabaiSettings(
        layout: .bsp, topPadding: 12, bottomPadding: 12, leftPadding: 24, rightPadding: 24,
        gap: 8, rules: [])
}
