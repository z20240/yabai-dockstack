import Foundation

/// Where a window should travel: an absolute yabai space index, or the
/// previous/next space on its current display (wrapping at the ends).
public enum SpaceTarget: Equatable {
    case index(Int)
    case prev
    case next

    /// Parses the wire/CLI form: "prev" | "next" | "1".."N".
    public static func parse(_ s: String) -> SpaceTarget? {
        switch s {
        case "prev": return .prev
        case "next": return .next
        default:
            guard let n = Int(s), n >= 1 else { return nil }
            return .index(n)
        }
    }
}

public enum ArrowDirection: String, Equatable { case left, right }

public enum TravelStep: Equatable {
    /// Re-position the window into another display's frame (AX move — SIP-free),
    /// landing on that display's currently visible space.
    case moveToDisplay(display: Int, x: Double, y: Double)
    /// Simulated titlebar drag + ctrl+left/right presses within one display.
    case arrowWalk(direction: ArrowDirection, count: Int)
}

public struct TravelPlan: Equatable {
    public let steps: [TravelStep]
    public let sourceSpace: Int
    public let targetSpace: Int
    public init(steps: [TravelStep], sourceSpace: Int, targetSpace: Int) {
        self.steps = steps; self.sourceSpace = sourceSpace; self.targetSpace = targetSpace
    }
}

/// Pure planning for SIP-free space moves. Mission Control's ctrl+arrows only
/// travel within one display, so cross-display targets first hop displays via
/// an absolute AX move, then walk from that display's visible space.
public enum SpaceTravelPlanner {
    public static func plan(target: SpaceTarget, windowSpace: Int, windowDisplay: Int,
                            spaces: [SpaceInfo], displays: [DisplayInfo]) -> TravelPlan? {
        let targetSpace: Int
        switch target {
        case .prev, .next:
            let list = orderedSpaces(on: windowDisplay, in: spaces)
            guard list.count > 1, let i = list.firstIndex(of: windowSpace) else { return nil }
            let j = target == .next ? (i + 1) % list.count : (i - 1 + list.count) % list.count
            targetSpace = list[j]
        case .index(let n):
            targetSpace = n
        }
        guard targetSpace != windowSpace,
              let targetDisplay = spaces.first(where: { $0.index == targetSpace })?.display else {
            return nil
        }

        var steps: [TravelStep] = []
        var walkFrom = windowSpace
        if targetDisplay != windowDisplay {
            guard let frame = displays.first(where: { $0.index == targetDisplay })?.frame,
                  let visible = spaces.first(where: { $0.display == targetDisplay && $0.isVisible })
            else { return nil }
            steps.append(.moveToDisplay(display: targetDisplay,
                                        x: frame.x + frame.w / 4, y: frame.y + frame.h / 4))
            walkFrom = visible.index
        }

        let list = orderedSpaces(on: targetDisplay, in: spaces)
        guard let from = list.firstIndex(of: walkFrom),
              let to = list.firstIndex(of: targetSpace) else { return nil }
        if to != from {
            steps.append(.arrowWalk(direction: to > from ? .right : .left, count: abs(to - from)))
        }
        guard !steps.isEmpty else { return nil }
        return TravelPlan(steps: steps, sourceSpace: windowSpace, targetSpace: targetSpace)
    }

    private static func orderedSpaces(on display: Int, in spaces: [SpaceInfo]) -> [Int] {
        spaces.filter { $0.display == display }.map(\.index).sorted()
    }
}
