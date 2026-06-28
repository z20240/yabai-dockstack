public struct Stack: Equatable {
    public let frame: YRect
    public let display: Int
    public let space: Int
    public let windows: [YabaiWindow]
    public let isFocused: Bool
    public let key: String

    public init(frame: YRect, display: Int, space: Int,
                windows: [YabaiWindow], isFocused: Bool, key: String) {
        self.frame = frame; self.display = display; self.space = space
        self.windows = windows; self.isFocused = isFocused; self.key = key
    }
}
