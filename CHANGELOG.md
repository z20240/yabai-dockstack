# Changelog

All notable changes to yabai-dockstack. Full release notes and downloads live on
the [GitHub Releases](https://github.com/z20240/yabai-dockstack/releases) page.

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
