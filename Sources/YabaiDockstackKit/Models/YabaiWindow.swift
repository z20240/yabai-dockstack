import Foundation

public struct YabaiWindow: Equatable {
    public let id: Int
    public let pid: Int
    public let app: String
    public let title: String
    public let frame: YRect
    public let display: Int
    public let space: Int
    public let stackIndex: Int
    public let hasFocus: Bool
    public let isVisible: Bool
    public let isFloating: Bool

    public init(id: Int, pid: Int, app: String, title: String, frame: YRect,
                display: Int, space: Int, stackIndex: Int, hasFocus: Bool,
                isVisible: Bool = true, isFloating: Bool = false) {
        self.id = id; self.pid = pid; self.app = app; self.title = title
        self.frame = frame; self.display = display; self.space = space
        self.stackIndex = stackIndex; self.hasFocus = hasFocus
        self.isVisible = isVisible
        self.isFloating = isFloating
    }

    private struct Raw: Decodable {
        struct Frame: Decodable { let x: Double; let y: Double; let w: Double; let h: Double }
        let id: Int
        let pid: Int
        let app: String
        let title: String?
        let frame: Frame
        let display: Int
        let space: Int
        let stackIndex: Int
        let hasFocus: Bool
        let isVisible: Bool?
        let isFloating: Bool?
        enum CodingKeys: String, CodingKey {
            case id, pid, app, title, frame, display, space
            case stackIndex = "stack-index"
            case hasFocus = "has-focus"
            case isVisible = "is-visible"
            case isFloating = "is-floating"
        }
    }

    /// Decodes a yabai `query --windows` array, skipping malformed entries. Never throws.
    public static func decodeList(_ data: Data) -> [YabaiWindow] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
        var out: [YabaiWindow] = []
        let decoder = JSONDecoder()
        for element in arr {
            guard let elementData = try? JSONSerialization.data(withJSONObject: element),
                  let raw = try? decoder.decode(Raw.self, from: elementData) else { continue }
            out.append(YabaiWindow(
                id: raw.id, pid: raw.pid, app: raw.app, title: raw.title ?? "",
                frame: YRect(x: raw.frame.x, y: raw.frame.y, w: raw.frame.w, h: raw.frame.h),
                display: raw.display, space: raw.space,
                stackIndex: raw.stackIndex, hasFocus: raw.hasFocus,
                isVisible: raw.isVisible ?? true, isFloating: raw.isFloating ?? false))
        }
        return out
    }
}
