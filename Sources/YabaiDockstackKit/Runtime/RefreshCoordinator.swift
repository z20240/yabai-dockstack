import Foundation

public final class RefreshCoordinator {
    private var config: AppConfig
    private let client: YabaiClient
    private let onStacks: ([Stack]) -> Void
    private let queue = DispatchQueue(label: "refresh.coordinator")
    private var pending: DispatchWorkItem?
    private var pollTimer: Timer?
    private var started = false
    private var last: [Stack] = []
    /// Raw (unfiltered) window list from each refresh — feeds the switcher's MRU.
    /// Called on the coordinator's queue; the receiver hops threads itself.
    public var onWindows: (([YabaiWindow]) -> Void)?

    public init(config: AppConfig, client: YabaiClient, onStacks: @escaping ([Stack]) -> Void) {
        self.config = config
        self.client = client
        self.onStacks = onStacks
    }

    /// Apply new timing (debounce / poll). Reschedules the poll timer.
    public func updateConfig(_ config: AppConfig) {
        self.config = config
        if started { schedulePollTimer() }
    }

    public func requestRefresh() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.run() }
        pending = work
        queue.asyncAfter(deadline: .now() + config.debounceSeconds, execute: work)
    }

    private func run() {
        let raw = client.queryWindows()
        onWindows?(raw)
        let windows = VisibleSpaceFilter.apply(raw)
        let stacks = StackBuilder.build(windows)
        if RefreshDiff.shouldRedraw(old: last, new: stacks) {
            last = stacks
            DispatchQueue.main.async { [weak self] in self?.onStacks(stacks) }
        }
    }

    public func start() {
        started = true
        requestRefresh()
        schedulePollTimer()
    }

    private func schedulePollTimer() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: config.pollSeconds, repeats: true) { [weak self] _ in
            self?.requestRefresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    public func stop() {
        started = false
        pollTimer?.invalidate()
        pollTimer = nil
        pending?.cancel()
    }
}
