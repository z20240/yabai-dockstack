import Foundation

public final class RefreshCoordinator {
    private let config: AppConfig
    private let client: YabaiClient
    private let onStacks: ([Stack]) -> Void
    private let queue = DispatchQueue(label: "refresh.coordinator")
    private var pending: DispatchWorkItem?
    private var pollTimer: Timer?
    private var last: [Stack] = []

    public init(config: AppConfig, client: YabaiClient, onStacks: @escaping ([Stack]) -> Void) {
        self.config = config
        self.client = client
        self.onStacks = onStacks
    }

    public func requestRefresh() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.run() }
        pending = work
        queue.asyncAfter(deadline: .now() + config.debounceSeconds, execute: work)
    }

    private func run() {
        let windows = VisibleSpaceFilter.apply(client.queryWindows())
        let stacks = StackBuilder.build(windows)
        if RefreshDiff.shouldRedraw(old: last, new: stacks) {
            last = stacks
            DispatchQueue.main.async { [weak self] in self?.onStacks(stacks) }
        }
    }

    public func start() {
        requestRefresh()
        let timer = Timer(timeInterval: config.pollSeconds, repeats: true) { [weak self] _ in
            self?.requestRefresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    public func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        pending?.cancel()
    }
}
