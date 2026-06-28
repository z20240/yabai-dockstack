import AppKit
import CoreGraphics

/// Orchestrates the Dock-hover preview: watch the Dock, group the hovered app's
/// windows, show thumbnails (live → cached → icon), and focus on click.
public final class DockPreviewController {
    private let client: YabaiClient
    private let cache: ThumbnailCache
    private let capturer = ThumbnailCapturer()
    private let panel = DockPreviewPanel()
    private var watcher: DockWatcher?
    private var hideWork: DispatchWorkItem?

    public init(client: YabaiClient, cache: ThumbnailCache) {
        self.client = client
        self.cache = cache
    }

    public func start() {
        guard PermissionsHelper.hasAccessibility() else { return }
        // Moving the cursor onto the panel keeps it open (the global mouse monitor
        // doesn't see events over our own panel, so the panel reports them itself).
        panel.onMouseEnter = { [weak self] in self?.hideWork?.cancel() }
        panel.onMouseExit = { [weak self] in self?.scheduleHide() }
        let w = DockWatcher { [weak self] hover in self?.handle(hover) }
        w.start()
        watcher = w
    }

    public func stop() {
        watcher?.stop(); watcher = nil
        panel.hide()
    }

    private func icon(for win: YabaiWindow) -> NSImage {
        NSRunningApplication(processIdentifier: pid_t(win.pid))?.icon
            ?? NSWorkspace.shared.icon(for: .applicationBundle)
    }

    private func items(for wins: [YabaiWindow]) -> [PreviewItem] {
        wins.map { win in
            PreviewItem(windowID: win.id, title: win.title, space: win.space,
                        thumbnail: cache.get(win.id), icon: icon(for: win))
        }
    }

    private func handle(_ hover: DockHover?) {
        guard let hover else { scheduleHide(); return }
        hideWork?.cancel()

        let wins = AppWindowGrouper.windows(of: hover.appTitle, in: client.queryWindows())
        guard !wins.isEmpty else { panel.hide(); return }

        // Show immediately with cached/icon, then refresh live thumbnails async.
        panel.show(items: items(for: wins), aboveIcon: hover.iconFrame) { [weak self] id in
            self?.client.focus(windowId: id); self?.panel.hide()
        }

        Task { [weak self] in
            guard let self else { return }
            let fresh = await self.capturer.captureOnScreen(windowIDs: Set(wins.map { $0.id }))
            guard !fresh.isEmpty else { return }
            for (id, img) in fresh { self.cache.put(id, img) }
            await MainActor.run {
                guard self.panel.isVisible else { return }
                self.panel.show(items: self.items(for: wins), aboveIcon: hover.iconFrame) { [weak self] id in
                    self?.client.focus(windowId: id); self?.panel.hide()
                }
            }
        }
    }

    private func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.panel.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    /// Warm the cache with currently on-screen windows (call on yabai signals).
    public func warmCache() {
        let ids = Set(client.queryWindows().map { $0.id })
        Task { [weak self] in
            guard let self else { return }
            let fresh = await self.capturer.captureOnScreen(windowIDs: ids)
            for (id, img) in fresh { self.cache.put(id, img) }
        }
    }
}
