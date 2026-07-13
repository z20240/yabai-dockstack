import AppKit

/// Orchestrates the window switcher: builds the item list (MRU + scope +
/// search), drives the panel, and commits focus via yabai. Fed by the key tap
/// (hold mode), the show-switcher socket command (sticky mode), and refresh
/// ticks (MRU + a warm window list so activation paints instantly).
public final class SwitcherController {
    private let client: YabaiClient
    private let cache: ThumbnailCache
    private let capturer = ThumbnailCapturer()
    private let panel = SwitcherPanel()
    private var config: AppConfig

    private var mru = MRUOrder()
    private var lastWindows: [YabaiWindow] = []
    private var items: [SwitcherItem] = []
    private var selection = 0
    private var scope: SwitcherScope = .allWindows
    private var sticky = false
    private var query = ""
    private var generation = 0   // invalidates in-flight async refreshes on hide/reopen
    /// Focus we just set ourselves; refresh reads that still predate it must
    /// not touch the MRU or fast alt-tab toggling lands on the wrong window.
    private var lastCommitID: Int?
    private var lastCommitAt: Date?
    /// Where the pointer sat when the panel (re)rendered — hover is ignored
    /// until it actually moves, so a stationary mouse can't hijack the
    /// keyboard selection when tracking areas rebuild.
    private var pointerGate: CGPoint?

    /// Fired whenever the panel closes for any reason; the app uses it to
    /// reset the key tap's machine (e.g. after a mouse-click commit mid-hold).
    public var onDismiss: (() -> Void)?

    public init(client: YabaiClient, cache: ThumbnailCache, config: AppConfig) {
        self.client = client
        self.cache = cache
        self.config = config
        panel.onHover = { [weak self] idx in
            guard let self else { return }
            if let gate = self.pointerGate {
                let p = NSEvent.mouseLocation
                guard abs(p.x - gate.x) > 4 || abs(p.y - gate.y) > 4 else { return }
                self.pointerGate = nil
            }
            self.select(idx)
        }
        panel.onClick = { [weak self] idx in self?.select(idx); self?.commit() }
        panel.onCloseItem = { [weak self] idx in self?.close(index: idx) }
        panel.onKeyEvent = { [weak self] ev in self?.handleStickyKey(ev) ?? false }
        panel.onResignKey = { [weak self] in
            guard let self, self.sticky else { return }
            self.cancel()
        }
    }

    public func updateConfig(_ c: AppConfig) { config = c }

    public var isOpen: Bool { panel.isVisible }

    /// Refresh feed (any thread): remember the raw list, keep the MRU in sync.
    /// A read taken before our own focus() landed still reports the previous
    /// window as focused — skip those touches for a beat after a commit.
    public func noteWindows(_ wins: [YabaiWindow]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastWindows = wins
            if let focused = wins.first(where: { $0.hasFocus }) {
                let staleWindow = self.lastCommitAt.map { Date().timeIntervalSince($0) < 1.0 } ?? false
                if !staleWindow || focused.id == self.lastCommitID {
                    self.mru.touch(focused.id)
                }
            }
            self.mru.prune(keeping: Set(wins.map { $0.id }))
        }
    }

    /// Open the switcher. Returns false when disabled or nothing to show, so
    /// the key tap can reset its machine instead of swallowing keys blindly.
    /// Hold mode must never block: it runs inside the event-tap callback,
    /// where a synchronous yabai query would stall all keyboard input, so it
    /// uses the cached list only (kept warm by every refresh tick).
    @discardableResult
    public func open(scope: SwitcherScope, sticky: Bool, backward: Bool = false) -> Bool {
        guard config.switcherEnabled else { return false }
        self.scope = scope
        self.sticky = sticky
        self.query = ""
        if lastWindows.isEmpty && sticky { lastWindows = client.queryWindows() }
        rebuildItems()
        if items.isEmpty && !sticky { hide(); return false }
        let firstIsCurrent = items.first.map { $0.id == mru.ids.first || $0.hasFocus } ?? false
        selection = SwitcherModel.initialIndex(count: items.count,
                                               firstIsCurrent: firstIsCurrent,
                                               backward: backward)
        render()
        refreshAsync()
        return true
    }

    public func cycle(forward: Bool) {
        guard !items.isEmpty else { return }
        selection = (selection + (forward ? 1 : items.count - 1)) % items.count
        panel.updateSelection(selection)
    }

    public func move(dx: Int, dy: Int) {
        guard !items.isEmpty else { return }
        let cols = max(panel.columns, 1)
        var next = selection + dx + dy * cols
        if dy == 0 {
            next = (next + items.count) % items.count   // horizontal wraps
        } else if !items.indices.contains(next) {
            return                                       // vertical clamps
        }
        selection = next
        panel.updateSelection(selection)
    }

    public func commit() {
        guard items.indices.contains(selection) else { cancel(); return }
        let id = items[selection].id
        mru.touch(id)
        lastCommitID = id
        lastCommitAt = Date()
        hide()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.client.focus(windowId: id)
        }
    }

    public func cancel() { hide() }

    public func closeSelected() { close(index: selection) }

    // MARK: - Internals

    private func rebuildItems() {
        items = SwitcherModel.build(windows: lastWindows, mru: mru.ids,
                                    scope: scope, query: query)
    }

    private func displayItems() -> [SwitcherDisplayItem] {
        items.map { it in
            SwitcherDisplayItem(
                item: it,
                thumbnail: cache.get(it.id),
                icon: NSRunningApplication(processIdentifier: pid_t(it.pid))?.icon
                    ?? NSWorkspace.shared.icon(for: .applicationBundle))
        }
    }

    private func render() {
        pointerGate = NSEvent.mouseLocation
        panel.show(items: displayItems(),
                   appearance: SwitcherAppearance(rawValue: config.switcherAppearance) ?? .thumbnails,
                   selection: selection, query: query, keyboardFocus: sticky)
    }

    private func hide() {
        generation += 1
        sticky = false
        panel.hide()
        onDismiss?()
    }

    private func select(_ idx: Int) {
        guard items.indices.contains(idx), idx != selection else { return }
        selection = idx
        panel.updateSelection(selection)
    }

    private func close(index: Int) {
        guard items.indices.contains(index) else { return }
        let id = items[index].id
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.client.close(windowId: id)
            Thread.sleep(forTimeInterval: 0.3)   // yabai needs a beat to drop it
            DispatchQueue.main.async {
                guard self.panel.isVisible else { return }
                self.refreshAsync()
            }
        }
    }

    /// Re-query yabai and recapture on-screen thumbnails, then re-render in
    /// place (keeps the selected window selected by id).
    private func refreshAsync() {
        generation += 1
        let gen = generation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let wins = self.client.queryWindows()
            DispatchQueue.main.async { self.applyRefresh(wins, generation: gen) }
            Task { [weak self] in
                guard let self else { return }
                let fresh = await self.capturer.captureOnScreen(windowIDs: Set(wins.map { $0.id }))
                guard !fresh.isEmpty else { return }
                for (id, img) in fresh { self.cache.put(id, img) }
                await MainActor.run {
                    guard gen == self.generation, self.panel.isVisible else { return }
                    self.render()
                }
            }
        }
    }

    private func applyRefresh(_ wins: [YabaiWindow], generation gen: Int) {
        guard gen == generation, panel.isVisible else { return }
        lastWindows = wins
        let selectedID = items.indices.contains(selection) ? items[selection].id : nil
        rebuildItems()
        if items.isEmpty && !sticky { hide(); return }
        if let id = selectedID, let idx = items.firstIndex(where: { $0.id == id }) {
            selection = idx
        } else {
            selection = max(0, min(selection, items.count - 1))
        }
        render()
    }

    /// Sticky-mode keys (panel is key window). Returns true when consumed.
    private func handleStickyKey(_ ev: NSEvent) -> Bool {
        switch ev.keyCode {
        case 0x35: cancel(); return true                         // escape
        case 0x24, 0x4C: commit(); return true                   // return / enter
        case 0x30:                                               // tab cycles
            cycle(forward: !ev.modifierFlags.contains(.shift)); return true
        case 0x7B: move(dx: -1, dy: 0); return true
        case 0x7C: move(dx: 1, dy: 0); return true
        case 0x7E: move(dx: 0, dy: -1); return true
        case 0x7D: move(dx: 0, dy: 1); return true
        case 0x33:                                               // backspace edits search
            if !query.isEmpty { query.removeLast(); queryChanged() }
            return true
        default:
            guard !ev.modifierFlags.contains(.command),
                  !ev.modifierFlags.contains(.control),
                  let chars = ev.charactersIgnoringModifiers, !chars.isEmpty,
                  chars.rangeOfCharacter(from: .controlCharacters) == nil else { return false }
            query += chars
            queryChanged()
            return true
        }
    }

    private func queryChanged() {
        rebuildItems()
        selection = 0
        render()
    }
}
