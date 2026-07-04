import Foundation

/// Executes SIP-free window-to-space moves: parses socket commands, plans via
/// SpaceTravelPlanner, and performs the steps (AX display hop + simulated drag).
/// The scripts only route here when the scripting addition is unavailable.
public final class SpaceMover {
    private let client: YabaiClient
    private let simulator: SpaceSimulating
    private let queue = DispatchQueue(label: "yabai-dockstack.space-mover")

    public init(client: YabaiClient, simulator: SpaceSimulating = SpaceSimulator()) {
        self.client = client
        self.simulator = simulator
    }

    /// Wire form: "move-space prev" | "move-space next" | "move-space 4".
    /// Unknown commands are ignored. Returns immediately; work runs serially
    /// off the main thread (the walk blocks for ~0.3 s per step).
    public func handle(command: String) {
        let parts = command.split(separator: " ").map(String.init)
        guard parts.count == 2, parts[0] == "move-space",
              let target = SpaceTarget.parse(parts[1]) else { return }
        queue.async { [self] in moveFocusedWindow(to: target) }
    }

    private func moveFocusedWindow(to target: SpaceTarget) {
        guard let window = client.queryFocusedWindow() else {
            NSLog("yabai-dockstack: move-space aborted, no focused window")
            return
        }
        guard let plan = SpaceTravelPlanner.plan(
            target: target, windowSpace: window.space, windowDisplay: window.display,
            spaces: client.querySpacesInfo(), displays: client.queryDisplaysInfo()) else {
            NSLog("yabai-dockstack: move-space aborted, planner returned nil")
            return
        }

        for step in plan.steps {
            switch step {
            case .moveToDisplay(_, let x, let y):
                client.moveWindow(id: window.id, absX: x, absY: y)
                client.focus(windowId: window.id)  // activates the target display
                Thread.sleep(forTimeInterval: 0.15)
            case .arrowWalk(let direction, let count):
                // Re-query: the frame moved if a display hop happened.
                guard let fresh = client.queryFocusedWindow(), fresh.id == window.id else {
                    NSLog("yabai-dockstack: move-space aborted, focused window changed before arrow walk")
                    return
                }
                // Top-center: clear of the traffic lights and (in most apps)
                // of toolbar controls; the top strip is the drag region.
                let grabX = fresh.frame.x + fresh.frame.w / 2
                let grabY = fresh.frame.y + 8
                let observed = simulator.dragWalk(grabX: grabX, grabY: grabY,
                                                   direction: direction, count: count)
                if !observed {
                    NSLog("yabai-dockstack: move-space walk not fully observed (grab may have missed the titlebar)")
                }
            }
        }

        client.focus(windowId: window.id)
        client.balance(space: plan.sourceSpace)
        client.balance(space: plan.targetSpace)
    }
}
