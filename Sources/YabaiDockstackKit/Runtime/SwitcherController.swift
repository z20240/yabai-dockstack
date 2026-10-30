import AppKit

/// Orchestrates the window switcher: builds the item list (MRU + scope +
/// search), drives the panel, and commits focus via yabai. Fed by the key tap
/// (hold mode), the show-switcher socket command (sticky mode), and refresh
/// ticks (MRU + a warm window list so activation paints instantly).
public final class SwitcherController {
    private let client: YabaiClient
    private let focuser: WindowFocuser
    private let cache: ThumbnailCache
    private let capturer = ThumbnailCapturer()
    private let visibilityProbe = WindowVisibilityProbe()
    private let panel: SwitcherPanel
    /// The search (sticky) switcher's view: PR #4's Spaces View look.
    private let spacesPanel: SpacesPanel
    private var config: AppConfig

    private var mru = MRUOrder()
    private var lastWindows: [YabaiWindow] = []
    private var items: [SwitcherItem] = []
    private var selection = 0
    private var highlightedID: Int?
    private var scope: SwitcherScope = .allWindows
    private var sticky = false
    private var query = ""
    private var generation = 0   // invalidates in-flight async refreshes on hide/reopen
    /// Windows we've asked to close/quit but yabai still lists — hidden from
    /// the panel immediately (optimistic) until the queries catch up.
    private var pendingCloseIDs: Set<Int> = []
    /// Focus we just set ourselves; refresh reads that still predate it must
    /// not touch the MRU or fast alt-tab toggling lands on the wrong window.
    private var lastCommitID: Int?
    private var lastCommitAt: Date?
    /// Where the pointer sat when the panel (re)rendered — hover is ignored
    /// until it actually moves, so a stationary mouse can't hijack the
    /// keyboard selection when tracking areas rebuild.
    private var pointerGate: CGPoint?
    /// Sticky (search) mode shows one card per space so windows (and whole
    /// spaces) can be dragged between them; nil in hold mode.
    private var cards: [SpaceCard]?
    private var spaces: [SpaceInfo] = []
    private var spaceLabels: [Int: String] = [:]
    private var wallpaper: NSImage?
    private var wallpaperGeneration = 0

    /// A refresh arrived mid-drag: replacing the cells would break the drag,
    /// so render once it ends.
    private var renderPending = false
    /// Our own SA moves can activate another app; a resign-key while they run
    /// (or just after) must not close the panel.
    private var ignoreResignUntil: Date?
    private var mutationsInFlight = 0
    /// Moves dropped windows / swaps spaces. Set by the app.
    public var mover: WindowSpaceMover?
    /// SIP doesn't change without a reboot: probe once.
    private lazy var saAvailable: Bool = SAProbe.current()

    /// Fired whenever the panel closes for any reason; the app uses it to
    /// reset the key tap's machine (e.g. after a mouse-click commit mid-hold).
    public var onDismiss: (() -> Void)?

    public convenience init(client: YabaiClient, cache: ThumbnailCache, config: AppConfig, focuser: WindowFocuser? = nil) {
        self.init(client: client, cache: cache, config: config, focuser: focuser,
                  panel: SwitcherPanel(), spacesPanel: SpacesPanel())
    }

    init(client: YabaiClient, cache: ThumbnailCache, config: AppConfig, focuser: WindowFocuser? = nil,
         panel: SwitcherPanel, spacesPanel: SpacesPanel) {
        self.panel = panel
        self.spacesPanel = spacesPanel
        self.focuser = focuser ?? WindowFocuser(client: client)
        self.client = client
        self.cache = cache
        self.config = config
        panel.onHover = { [weak self] idx in
            guard let self else { return }
            guard SpacesInteraction.hoverPasses(gate: self.pointerGate, pointer: NSEvent.mouseLocation) else { return }
            self.pointerGate = nil
            self.select(idx)
        }
        panel.onClick = { [weak self] idx in self?.select(idx); self?.commit() }
        panel.onCloseItem = { [weak self] idx in self?.close(index: idx) }
        panel.onKeyEvent = { [weak self] ev in self?.handleStickyKey(ev) ?? false }
        panel.onResignKey = { [weak self] in
            guard let self, self.sticky else { return }
            self.cancel()
        }
        spacesPanel.onHover = { [weak self] id in
            guard let self, let idx = self.items.firstIndex(where: { $0.id == id }),
                  SpacesInteraction.hoverPasses(gate: self.pointerGate, pointer: NSEvent.mouseLocation) else { return }
            self.pointerGate = nil
            self.highlightedID = id
            self.select(idx)
            self.spacesPanel.updateSelection(id)
        }
        spacesPanel.onHoverExit = { [weak self] id in
            guard let self, self.highlightedID == id else { return }
            self.highlightedID = nil
            self.spacesPanel.updateSelection(nil)
        }
        spacesPanel.onClick = { [weak self] id in
            guard let self, let idx = self.items.firstIndex(where: { $0.id == id }) else { return }
            self.select(idx)
            self.commit()
        }
        spacesPanel.onCloseItem = { [weak self] id in
            guard let self, let idx = self.items.firstIndex(where: { $0.id == id }) else { return }
            self.close(index: idx)
        }
        spacesPanel.onWindowDrop = { [weak self] id, space in self?.dropWindow(id, on: space) }
        spacesPanel.onSpaceDrop = { [weak self] a, b in self?.swapSpaces(a, b) }
        spacesPanel.onSpaceClick = { [weak self] space in self?.clickSpace(space) }
        spacesPanel.onDragEnded = { [weak self] in
            guard let self, self.renderPending else { return }
            self.renderPending = false
            self.render()
        }
        spacesPanel.onKeyEvent = { [weak self] ev in self?.handleStickyKey(ev) ?? false }
        spacesPanel.onResignKey = { [weak self] in
            guard let self, self.sticky else { return }
            if self.mutationsInFlight > 0 || (self.ignoreResignUntil.map { Date() < $0 } ?? false) {
                // Let the window server finish handing key status over first.
                DispatchQueue.main.async { self.spacesPanel.regainKey() }
            } else {
                self.cancel()
            }
        }
        refreshWallpaper()
    }

    public func updateConfig(_ c: AppConfig) {
        config = c
        refreshWallpaper()
    }

    public var isOpen: Bool { panel.isVisible || spacesPanel.isVisible }

    private func displayableWindows(_ wins: [YabaiWindow]) -> [YabaiWindow] {
        let filtered = visibilityProbe.liveWindowIDs(wins).map { ids in
            wins.filter { ids.contains($0.id) }
        } ?? wins
        return SpacesModel.displayableWindows(filtered)  // drops yabai scratchpad windows
    }

    /// Refresh feed (any thread): remember the raw list, keep the MRU in sync.
    /// A read taken before our own focus() landed still reports the previous
    /// window as focused — skip those touches for a beat after a commit.
    public func noteWindows(_ wins: [YabaiWindow]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let displayable = self.displayableWindows(wins)
            self.lastWindows = displayable
            if let focused = displayable.first(where: { $0.hasFocus }) {
                let staleWindow = self.lastCommitAt.map { Date().timeIntervalSince($0) < 1.0 } ?? false
                if !staleWindow || focused.id == self.lastCommitID {
                    self.mru.touch(focused.id)
                }
            }
            self.mru.prune(keeping: Set(displayable.map { $0.id }))
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
        if sticky { panel.hide() } else { spacesPanel.hide() }  // never both on screen
        self.query = ""
        rebuildItems()
        if items.isEmpty && !sticky { hide(); return false }
        // Start on the previous window by MRU, wherever its section put it.
        let mruOrder = SwitcherModel.build(windows: lastWindows, mru: mru.ids, scope: scope, query: query)
            .filter { !pendingCloseIDs.contains($0.id) }
        let firstIsCurrent = mruOrder.first.map { $0.id == mru.ids.first || $0.hasFocus } ?? false
        let start = SwitcherModel.initialIndex(count: mruOrder.count,
                                               firstIsCurrent: firstIsCurrent,
                                               backward: backward)
        selection = mruOrder.indices.contains(start)
            ? (items.firstIndex { $0.id == mruOrder[start].id } ?? 0) : 0
        highlightedID = items.indices.contains(selection) ? items[selection].id : nil
        render()
        refreshAsync()
        return true
    }

    public func cycle(forward: Bool) {
        guard !items.isEmpty else { return }
        selection = (selection + (forward ? 1 : items.count - 1)) % items.count
        showSelection()
    }

    public func move(dx: Int, dy: Int) {
        guard !items.isEmpty else { return }
        if dy != 0, cards != nil {  // tiles aren't on a grid: nearest one above / below
            let rects = items.map { spacesPanel.tileFrames[$0.id] ?? .zero }
            if let n = SpatialNav.neighbor(of: selection, up: dy < 0, rects: rects) {
                selection = n
                showSelection()
            }
            return
        }
        let cols = max(panel.columns, 1)
        var next = selection + dx + dy * cols
        if dy == 0 {
            next = (next + items.count) % items.count   // horizontal wraps
        } else if !items.indices.contains(next) {
            return                                       // vertical clamps
        }
        selection = next
        showSelection()
    }

    public func commit() {
        // Search switcher with nothing matching or nothing highlighted: Enter does nothing.
        guard let idx = actionIndex else { if !sticky { cancel() }; return }
        let id = items[idx].id
        mru.touch(id)
        lastCommitID = id
        lastCommitAt = Date()
        hide()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.focuser.focus(windowId: id)
        }
    }

    public func cancel() { hide() }

    public func closeSelected() {
        if let idx = actionIndex { close(index: idx) }
    }

    /// The window keyboard actions apply to (the search switcher's highlight
    /// can be gone after the pointer leaves a tile).
    private var actionIndex: Int? {
        SpacesInteraction.actionIndex(selection: selection, count: items.count,
                                      highlighted: cards == nil || highlightedID != nil)
    }

    // MARK: - Internals

    private func rebuildItems() {
        // Forget pending ids once yabai actually dropped the window.
        pendingCloseIDs.formIntersection(Set(lastWindows.map { $0.id }))
        items = SwitcherModel.build(windows: lastWindows, mru: mru.ids,
                                    scope: scope, query: query)
            .filter { !pendingCloseIDs.contains($0.id) }
        if sticky {
            // An empty space cache on first open is still search mode. Show
            // the Spaces panel's search box until refreshAsync fills its cards,
            // rather than opening the hold panel and leaving it behind later.
            // Every window gets a tile; the query only decides which are lit.
            let all = SwitcherModel.build(windows: lastWindows, mru: mru.ids, scope: scope, query: "")
                .filter { !pendingCloseIDs.contains($0.id) }
            let c = SpacesSwitcherModel.build(items: all, windows: lastWindows, spaces: spaces,
                                              labels: spaceLabels, matching: Set(items.map(\.id)))
            cards = c
            // Preserve the cached MRU selection while space metadata loads.
            if !spaces.isEmpty { items = SpacesSwitcherModel.selectable(c) }
        } else {
            cards = nil
        }
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
        if spacesPanel.isDragging { renderPending = true; return }
        pointerGate = NSEvent.mouseLocation
        if let cards {
            let ids = cards.flatMap { $0.tiles.map(\.item.id) }
            let thumbs = Dictionary(ids.compactMap { id in cache.get(id).map { (id, $0) } },
                                    uniquingKeysWith: { a, _ in a })
            spacesPanel.spaceDragEnabled = saAvailable
            spacesPanel.show(cards: cards, thumbnails: thumbs, wallpaper: config.switcherWallpaper ? wallpaper : nil,
                             query: query, selectedID: highlightedID)
        } else {
            panel.show(items: displayItems(),
                       appearance: SwitcherAppearance(rawValue: config.switcherAppearance) ?? .thumbnails,
                       selection: selection, query: query, keyboardFocus: sticky)
        }
    }

    private func hide() {
        generation += 1
        sticky = false
        ignoreResignUntil = nil
        mutationsInFlight = 0
        renderPending = false
        panel.hide()
        spacesPanel.hide()
        onDismiss?()
    }

    private func select(_ idx: Int) {
        guard items.indices.contains(idx), idx != selection else { return }
        selection = idx
        showSelection()
    }

    private func showSelection() {
        if cards != nil {
            highlightedID = items.indices.contains(selection) ? items[selection].id : nil
            spacesPanel.updateSelection(highlightedID)
        } else {
            panel.updateSelection(selection)
        }
    }

    // MARK: - Search switcher: moves, swaps, card clicks

    private func dropWindow(_ id: Int, on space: Int) {
        let fullscreen = Set(spaces.filter(\.isNativeFullscreen).map(\.index))
        guard let mover, let window = lastWindows.first(where: { $0.id == id }),
              SpacesInteraction.moveAllowed(from: window.space, to: space, fullscreen: fullscreen) else { return }
        renderPending = false
        if saAvailable && !config.switcherFollowMove {
            // Instant yabai move: stay open so several windows can be moved.
            mutationsInFlight += 1
            mover.move(windowId: id, toSpace: space, follow: false) { [weak self] in self?.afterMutation() }
        } else {
            hide()  // the SIP-free walk needs the real window, not our panel, under the cursor
            mover.move(windowId: id, toSpace: space, follow: true)
        }
    }

    private func swapSpaces(_ a: Int, _ b: Int) {
        let fullscreen = Set(spaces.filter(\.isNativeFullscreen).map(\.index))
        guard let mover, SpacesInteraction.swapAllowed(source: a, target: b, saAvailable: saAvailable,
                                                        fullscreen: fullscreen) else { return }
        mutationsInFlight += 1
        mover.swapSpaces(a, b) { [weak self] in self?.afterMutation() }
    }

    private func clickSpace(_ space: Int) {
        let tiles = cards?.first { $0.space == space }?.tiles.map(\.item.id) ?? []
        let recent = SpacesInteraction.recentWindow(inSpace: space, mru: mru.ids, tilesInSpace: tiles)
        let action = SpacesInteraction.cardClick(space: space, saAvailable: saAvailable,
                                                 recentWindowInSpace: recent)
        guard action != .nothing else { return }
        hide()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            switch action {
            case .focusSpace(let s): self.client.focus(spaceId: s)
            case .focusWindow(let id): self.focuser.focus(windowId: id)
            case .nothing: break
            }
        }
    }

    private func afterMutation() {
        mutationsInFlight = max(0, mutationsInFlight - 1)
        ignoreResignUntil = Date().addingTimeInterval(0.5)  // a late resign from the move itself
        guard spacesPanel.isVisible else { return }
        spacesPanel.regainKey()
        refreshAsync()
    }

    /// The space you're on changed (e.g. a swipe) while the panel is open.
    public func noteActiveSpaceChanged() {
        guard spacesPanel.isVisible else { return }
        // Space changes can make the window server briefly revoke key status.
        // Keep the sticky search switcher alive while its cards are refreshed.
        ignoreResignUntil = Date().addingTimeInterval(0.5)
        spacesPanel.regainKey()
        refreshAsync()
    }

    /// (Re)load the configured wallpaper — dark variant in dark mode.
    public func refreshWallpaper() {
        wallpaperGeneration += 1
        let request = wallpaperGeneration
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let path = dark && !config.switcherWallpaperDarkPath.isEmpty
            ? config.switcherWallpaperDarkPath : config.switcherWallpaperPath
        guard config.switcherWallpaper, !path.isEmpty else { wallpaper = nil; return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let image = NSImage(contentsOfFile: path)
            DispatchQueue.main.async {
                guard let self, request == self.wallpaperGeneration else { return }
                self.wallpaper = image
                if self.spacesPanel.isVisible { self.render() }
            }
        }
    }

    /// Drop the pending-close cells right away; hide when nothing is left.
    private func applyPendingRemoval() {
        rebuildItems()
        if items.isEmpty && !sticky { hide(); return }
        selection = max(0, min(selection, items.count - 1))
        render()
    }

    private func close(index: Int) {
        guard items.indices.contains(index) else { return }
        let id = items[index].id
        pendingCloseIDs.insert(id)
        applyPendingRemoval()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.client.close(windowId: id)
            Thread.sleep(forTimeInterval: 0.4)   // yabai needs a beat to drop it
            DispatchQueue.main.async {
                guard self.isOpen else { return }
                self.refreshAsync()              // reconcile (e.g. close was refused)
            }
        }
    }

    /// ⌘Q — gracefully quit the selected window's whole application.
    public func quitSelected() {
        guard let idx = actionIndex else { return }
        let pid = items[idx].pid
        pendingCloseIDs.formUnion(items.filter { $0.pid == pid }.map { $0.id })
        applyPendingRemoval()
        NSRunningApplication(processIdentifier: pid_t(pid))?.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.isOpen else { return }
            self.refreshAsync()
        }
    }

    /// Re-query yabai and recapture on-screen thumbnails, then re-render in
    /// place (keeps the selected window selected by id).
    private func refreshAsync() {
        generation += 1
        let gen = generation
        let wantSpaces = sticky
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let wins = self.displayableWindows(self.client.queryWindows())
            let freshSpaces = wantSpaces ? self.client.querySpacesInfo() : nil
            let freshLabels = wantSpaces ? self.client.querySpaceLabels() : nil
            DispatchQueue.main.async {
                if let freshSpaces, !freshSpaces.isEmpty { self.spaces = freshSpaces }
                if let freshLabels { self.spaceLabels = freshLabels }
                self.applyRefresh(wins, generation: gen)
            }
            Task { [weak self] in
                guard let self else { return }
                let fresh = await self.capturer.captureOnScreen(windowIDs: Set(wins.map { $0.id }))
                guard !fresh.isEmpty else { return }
                for (id, img) in fresh { self.cache.put(id, img) }
                await MainActor.run {
                    guard gen == self.generation, self.isOpen else { return }
                    self.render()
                }
            }
        }
    }

    private func applyRefresh(_ wins: [YabaiWindow], generation gen: Int) {
        guard gen == generation, isOpen else { return }
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
        if ev.modifierFlags.contains(.command) {
            switch ev.keyCode {
            case 0x0D: closeSelected(); return true    // ⌘W
            case 0x0C: quitSelected(); return true     // ⌘Q
            case 0x33: query = ""; queryChanged(); return true // ⌘⌫
            default: return false
            }
        }
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
            if ev.modifierFlags.contains(.option) {
                deleteSearchWord()
            } else if !query.isEmpty {
                query.removeLast()
                queryChanged()
            }
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

    private func deleteSearchWord() {
        guard !query.isEmpty else { return }
        while let last = query.last, last.isWhitespace {
            query.removeLast()
        }
        while let last = query.last, !last.isWhitespace {
            query.removeLast()
        }
        queryChanged()
    }

    private func queryChanged() {
        rebuildItems()
        // The best match by recency, wherever its card sits.
        let first = SwitcherModel.build(windows: lastWindows, mru: mru.ids, scope: scope, query: query)
            .first { !pendingCloseIDs.contains($0.id) }
        selection = first.flatMap { f in items.firstIndex { $0.id == f.id } } ?? 0
        render()
    }
}
