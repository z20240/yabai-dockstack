# Changelog

All notable changes to yabai-dockstack. Full release notes and downloads live on
the [GitHub Releases](https://github.com/z20240/yabai-dockstack/releases) page.

## v0.4.0 — 2026-11-12

- **Your rc files are yours** (#11, thanks @Signynt): dockstack no longer edits
  `yabairc` / `skhdrc` unless you turn on **Allow dockstack to edit yabairc** /
  **…skhdrc** (Settings → yabai / Keyboard). Both are off by default; if your rc
  already has a dockstack-managed section, the matching option is switched on
  once at upgrade. Nothing is written on launch any more.
- **Read-only view that shows what you really run**: with editing off, the yabai
  tab shows yabai's live settings and marks values that differ from the file with
  a `!` (hover for details); the Keyboard tab shows the bindings actually in your
  `skhdrc`, with everything else under a collapsed **Other shortcuts** list
  (rules with extra conditions go under **Other rules**). **Reload** re-reads.
- **Config-file row**: shows the rc in use (detected in yabai's / skhd's own
  lookup order, honouring `-c`), with **Choose…**, **Reset to auto** and
  **Open in editor**.
- **Apply asks first**: before commenting out hand-written lines it now manages
  (prefixed `# [yabai-dockstack imported]`, never deleted, `.bak` kept) or adding
  a managed section, Apply shows a confirmation. Rules with extra conditions,
  indented lines and lines dockstack can't represent are left alone. The Switcher
  tab's search hotkey uses the same confirmation.
- **Safer writes**: refuses rc files with broken managed markers or that aren't
  readable text, and never overwrites an unreadable `config.json` with defaults.

## v0.3.2 — 2026-10-22

- **Keyboard settings**: a shortcut with no hotkey yet (such as the new
  Pin / unpin window on top) no longer pushes its Record Hotkey button out of
  line with the other rows.

## v0.3.1 — 2026-10-22

- **Pin windows on top** (#7) — needs yabai's scripting addition:
  - a new Window Rules mode, **Float & pin on top**, keeps an app's windows
    floating above the others (`manage=off sub-layer=above`);
  - a **Pin / unpin window on top** shortcut (Keyboard → Shared, unbound by
    default) toggles the focused window; a tiled window is floated while pinned
    and re-tiled when unpinned. Without the scripting addition it does nothing.
- **Window strip**:
  - follows light / dark mode (same frosted material as the switcher);
  - empty spaces show as small named slots, so you can see which space each
    window is in, and every display with spaces gets a strip;
  - drag a window onto **another display's** strip to move it there; a copy of
    the chip follows the pointer while dragging;
  - hover a window for a ✕ to close it;
  - drops follow the same rule as the search switcher: with the scripting
    addition the move is instant unless "follow the window" is on.
- **Search switcher** (thanks @Signynt, #6):
  - its hotkey now toggles it open / closed;
  - it stays open when the space changes, opens faster, and marks the current
    space sooner;
  - ⌘⌫ clears the search, ⌥⌫ deletes a word;
  - a tighter selection highlight that clears when the pointer leaves a window
    (Enter / ⌘W / ⌘Q then do nothing until something is highlighted again), and
    a pointer resting where the switcher opens no longer steals the selection.

## v0.3.0 — 2026-10-20

- **Spaces-style search switcher & drag windows between spaces** (based on
  @Signynt's Spaces View, #4) — the search switcher now shows every space as a
  mini desktop, grouped by display, with its windows tiled inside, a project-name
  capsule on each, and the space you're on marked "Current". Typing dims the
  windows that don't match. Drag a window onto another space to move it there,
  even from a space you're not on (the window strip takes drops too):
  - with yabai's scripting addition the move is instant and the switcher stays
    open (optionally follow the window: Settings → Switcher);
  - with SIP on the window is focused and walked over with the simulated gesture,
    and you end on the destination space.
  Drag a whole space card onto another to **swap their windows** — this needs
  the scripting addition. Click a card to go to that space. Optional wallpaper on
  the cards. The search switcher's hotkey can now be recorded on the Switcher tab.
- **Project-aware window labels** — windows of the same app are labelled by
  what tells them apart: VS Code / Cursor / Windsurf → workspace, JetBrains →
  project, terminals → current folder, otherwise the part of the title that
  differs. Shown first (bold) in switcher captions, Dock previews, the window
  menu and the window strip; the full title is on hover.
- **Window strip** (opt-in) — one strip per display under the menu bar listing
  that display's windows (icon + project-aware label, divider between spaces);
  click to jump, hover for title and space, resizable from Settings, "+N"
  overflow opens the menu; hidden over native-fullscreen spaces.
- **Hover to open the window menu** (opt-in).
- **Auto-adjust yabai padding** (opt-in, Settings → Appearance) — sizes yabai's
  left/right padding for the stack indicators and the top padding for the window
  strip, live, following their size; restored when turned off or on quit.
- **Restart yabai-dockstack** from the menu bar menu.
- **Dock previews match the rest of the app** — same frosted panel as the
  switcher, colours follow light/dark mode (thanks @Signynt, #5).
- **⌃-drag to reorder a stack** from its indicator (on by default; uses yabai
  `--swap`, works without the scripting addition).
- **Hyper Key** (opt-in) — Caps Lock / right ⌘ / ⌥ / ⌃ → ⌃⌥⌘(⇧), with quick
  press (Escape / toggle Caps Lock) and an optional ✦ display; restores the key
  on quit, SIGTERM, and the next launch after a crash.
- **Fixed: clicking tray-closed apps did nothing** — Gather, Surfshark and
  similar apps keep their closed window listed without an AX reference, so yabai
  can't focus it; the app is now reopened instead, which brings that window back.

## v0.2.16 — 2026-10-14

- **Click-through stack indicator** — new Settings option: clicks pass through
  the indicator to the window underneath (e.g. its close button); hover tooltips
  and click-to-focus are turned off. Off by default. ([#2](https://github.com/z20240/yabai-dockstack/issues/2))
- **Fixed stale / wrong stack indicators** — a sticky window (shown on all
  spaces) no longer makes a hidden space count as visible, so its stacks aren't
  drawn over the current one; indicators are no longer reused across spaces, so
  they don't linger after a stack is closed or unstacked.
- **More reliable SIP-free space moves** — the simulated drag verifies the window
  actually lifts and probes grab points, aborting cleanly instead of bouncing.

## v0.2.15 — 2026-07-14

- **Instant close sync** — closing a window from the Dock preview or the switcher
  removes its cell immediately (optimistic update), instead of a stale snapshot
  lingering until a re-hover.
- **Switcher: ⌘W / ⌘Q** — close the selected window / quit its whole app, in both
  hold-to-cycle and sticky modes.
- **Dock preview: last window quits the app** — ✕ on an app's last window
  terminates the app itself, so apps that merely hide on window close (Music, …)
  actually exit.

## v0.2.14 — 2026-07-14

- **Close from the Dock preview** — hovering a thumbnail reveals an ✕ that closes
  that window via yabai; the popover rebuilds in place.

## v0.2.13 — 2026-07-13

- **Single-instance guard** — a second copy (duplicate login items, session
  restore) now detects the first and exits, instead of two menu-bar icons
  fighting over the socket and event tap.

## v0.2.12 — 2026-07-13

- **AltTab-style window switcher** — hold **⌥⇥** to cycle every window on every
  space (thumbnails, most-recently-used order); **⌥`** for the current app only;
  Shift reverses, arrows navigate, W/✕ closes, Esc cancels, release to switch.
  Optional capture of the system **⌘⇥**.
- Three appearances (thumbnails / app icons / title list) with auto-sizing, a
  type-to-search sticky mode, per-scope hotkeys, and a new **Settings → Switcher**
  tab (en / 繁體中文 / 日本語).
- Fix: bundled helper scripts now resolve in universal (xcodebuild) builds —
  fresh installs previously couldn't install script-backed hotkeys.

## v0.2.11 — 2026-07-06

- **Open window menu** hotkey action (default ⌃,) + **quick-select keys** (1–9, 0,
  letters) on every window row while the menu is open.
- Fix: recorded punctuation hotkeys emit uppercase hex keycodes (skhd rejects
  lowercase).

## v0.2.10 — 2026-07-05

- **Full UI localization** — English / 繁體中文 / 日本語, with an in-app language
  picker (default: follow the system), guarded by string-table parity tests.
- SF Symbol icons next to every hotkey in the Keyboard pane.

## v0.2.9 — 2026-07-04

- Fix: cross-display space moves for tiled windows (float for the journey,
  re-tile on arrival).

## v0.2.8 — 2026-07-04

- **SIP-free space moves** — the send-to-space hotkeys (⌃⌘←/→, ⌃⌘1–9) work with
  SIP fully enabled by simulating the native drag + Mission Control gesture;
  the instant yabai path is still used when the scripting addition is loaded.

## v0.2.7 — 2026-06-30

- **Import existing config** — recognized hand-written `~/.yabairc` / `~/.skhdrc`
  bindings are pulled into the managed region (originals commented out), so the
  Settings UI becomes the single source of truth.

## v0.2.6 — 2026-06-30

- yabai Settings pane layout finally correct; Settings window title shows the
  app version. (v0.2.3–v0.2.5 were intermediate attempts at the same layout bug.)

## v0.2.2 — 2026-06-30

- Swapped **Float** / **Off** semantics to match their labels (Float = all
  windows float with floating-mode shortcuts; Off = yabai hands off entirely).

## v0.2.1 — 2026-06-30

- Fix: Default layout **Off** actually turns yabai management off.
- **⚙️ Edit raw file** opens rc files in a GUI editor (`open -t`).

## v0.2.0 — 2026-06-30

- **Settings UI for yabai & skhd** — three tabs (Appearance / yabai / Keyboard):
  layout, gaps & padding, window rules, and a Raycast-style hotkey list with
  conflict detection. Writes only to a clearly-marked managed region in your rc
  files, backs up to `.bak`, and never applies without pressing **Apply**.

## v0.1.4 — 2026-06-28

- Fix: Dock previews match apps by **bundle id** (VSCode's Dock name differs
  from yabai's app name).

## v0.1.3 — 2026-06-28

- First-run **yabai setup guide** when yabai isn't found.

## v0.1.2 — 2026-06-28

- Ad-hoc code signing so the Accessibility / Screen Recording grants stick.

## v0.1.1 — 2026-06-28

- Permissions section in Settings (live ✓/✗ + Grant… buttons); universal binary
  (Apple Silicon + Intel).

## v0.1.0 — 2026-06-28

- First release: **stack indicators**, **cross-space window menu**, and **Dock
  window previews** for yabai on macOS 14+.
