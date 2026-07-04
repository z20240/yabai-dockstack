import Foundation

/// Minimal projection of `yabai -m query --spaces` used for space-travel planning.
public struct SpaceInfo: Equatable {
    public let index: Int
    public let display: Int
    public let isVisible: Bool
    public init(index: Int, display: Int, isVisible: Bool) {
        self.index = index; self.display = display; self.isVisible = isVisible
    }

    /// Tolerant decode: skips malformed entries, returns [] on bad JSON.
    public static func decodeList(_ data: Data) -> [SpaceInfo] {
        guard let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return []
        }
        return arr.compactMap { s in
            guard let index = s["index"] as? Int, let display = s["display"] as? Int else {
                return nil
            }
            return SpaceInfo(index: index, display: display,
                             isVisible: s["is-visible"] as? Bool ?? false)
        }
    }
}

/// Minimal projection of `yabai -m query --displays`.
public struct DisplayInfo: Equatable {
    public let index: Int
    public let frame: YRect
    public init(index: Int, frame: YRect) { self.index = index; self.frame = frame }

    public static func decodeList(_ data: Data) -> [DisplayInfo] {
        guard let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return []
        }
        return arr.compactMap { d in
            guard let index = d["index"] as? Int,
                  let f = d["frame"] as? [String: Any],
                  let x = f["x"] as? Double, let y = f["y"] as? Double,
                  let w = f["w"] as? Double, let h = f["h"] as? Double else { return nil }
            return DisplayInfo(index: index, frame: YRect(x: x, y: y, w: w, h: h))
        }
    }
}
