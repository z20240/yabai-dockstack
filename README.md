<div align="center">

<img src="assets/banner.png" width="760" alt="yabai-dockstack — visual enhancements for yabai on macOS" />

English · [繁體中文](README.zh-Hant.md)

<sub>Inspired by [stackline](https://github.com/AdamWagner/stackline) and DockView ·
keywords: yabai, stackline, dockview, macOS window manager, tiling, stack indicator,
dock preview, window switcher, menu bar, Mission Control alternative</sub>

</div>

---

`yabai-dockstack` adds the visual layer that yabai lacks:

- **Stack indicators** — a floating indicator next to each window stack so you see, at
  a glance, which apps are stacked and in what order (inspired by **stackline**).
- **Cross-space window menu** — every window grouped by Display → Space in the menu
  bar; click to jump and focus.
- **Dock window previews** — hover a Dock icon to peek an app's windows across all
  spaces with thumbnails; click to jump (inspired by **DockView**).

It is a clean Swift rewrite — **not** a fork of stackline (which required Hammerspoon).

## Features

- 🚦 One floating indicator per stack, placed at the window's outer screen edge.
- 🅰️ **Icon mode** (default): app icons stacked top→bottom in stack-index order;
  focused window highlighted. **Flag mode**: slim minimal markers. Toggle from
  the menu bar.
- 🔎 **Hover** an indicator → popover with that window's full title.
- 🖱️ **Click** an indicator → focus that window (via yabai).
- 🖥️ Multi-monitor, all visible spaces.
- 🪶 No Hammerspoon. Minimal permissions (no Accessibility, no Screen Recording —
  focus is delegated to yabai).

## Requirements

- macOS 13+
- [yabai](https://github.com/koekeishiya/yabai) installed and running.
- To **build**: the Swift toolchain (Xcode or Command Line Tools — see note below).

## Build

```sh
./scripts/bundle.sh
```

This produces `yabai-dockstack.app` in the repo root and prints the absolute path
to the binary inside it.

> **Toolchain note.** The app builds with either full Xcode or the standalone
> Command Line Tools. If `swift build` complains about the Xcode license, either
> run `sudo xcodebuild -license accept`, or build against Command Line Tools:
> ```sh
> DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/bundle.sh
> ```
> Running the **XCTest** suite (`swift test`) requires full Xcode (XCTest is not
> shipped with Command Line Tools). A toolchain-independent check is available
> via `swift run yst-selftest` (see Testing).

## Install (zero manual config)

```sh
open yabai-dockstack.app
```

That's it. On launch the app:

- **auto-detects** the yabai binary (Homebrew Apple Silicon / Intel / nix, then `which`);
- **auto-registers** the yabai signals it needs (pointing at its own path), so you
  never edit `~/.yabairc`. This is idempotent — re-running is safe.

The menu-bar menu shows **yabai: connected ✓** when it found yabai, then a live
list of every window grouped by **Display → Space** (the focused window is
checked). Spaces show their custom yabai label if set (`yabai -m space --label`),
otherwise "Space N". Clicking a window jumps to its space and focuses it. It also
offers:

- **Settings…** — a window to adjust style (icon/flag), indicator size, focused/
  unfocused opacity, flag color, background pill + color, "keep inside window gap",
  full-width side, **Debounce (ms)** / **Poll interval (ms)**, **yabai path**
  (blank = auto-detect; a manual escape hatch if detection fails), and **Start at
  login**. Changes apply live and are saved.
- **Re-register yabai signals** — re-applies the signals if yabai was restarted.

> First launch of an unsigned app: macOS Gatekeeper will block it once. Right-click
> the app → **Open**, or run `xattr -dr com.apple.quarantine yabai-dockstack.app`.
> To remove this step entirely you'd need an Apple Developer ID signature +
> notarization.

> Move `yabai-dockstack.app` to `/Applications` before enabling **Start at login**
> so the login item points at a stable location.

### Manual setup (optional / fallback)

If you prefer to manage signals yourself (e.g. persisted in your dotfiles), the
legacy helpers are still provided: `examples/yabairc-signals.sh` (set `BIN`, source
from `~/.yabairc`) and `examples/com.yabai-dockstack.agent.plist` (a LaunchAgent).
You don't need these for the default flow.

## Configuration

Optional config file at `~/.config/yabai-dockstack/config.json`. Any omitted key
falls back to its default. All keys:

```json
{
  "yabaiPath": "/opt/homebrew/bin/yabai",
  "socketPath": "/tmp/yabai-dockstack.sock",
  "style": "icon",
  "cellSize": 32,
  "offset": 4,
  "focusedAlpha": 1.0,
  "unfocusedAlpha": 0.4,
  "debounceSeconds": 0.05,
  "pollSeconds": 3.0,
  "fullWidthSide": "left",
  "edgeInset": 6,
  "flagColor": "#4C8DFF"
}
```

- `fullWidthSide`: which edge the indicator goes to for a near-full-width window
  (≥90% of the screen), where there's no clear left/right bias. `"left"` (default)
  or `"right"`. Narrower windows still follow their on-screen position.
- `edgeInset`: extra pixels to keep the indicator off the very screen edge when it
  would otherwise clamp there (so it doesn't sit on a window's rounded corner).
- `flagColor`: flag-mode bar color, `"#RRGGBB"` or `"#RRGGBBAA"`.
- `showBackground`: draw a rounded backing pill behind the indicators so they read
  as a floating chip (helpful over full-width windows). `true`/`false`.
- `backgroundColor`: backing pill color, `"#RRGGBB"` / `"#RRGGBBAA"`.

Most of these are adjustable from **Settings…** in the menu bar (no file editing
needed). The config file is still created automatically on first launch at
`~/.config/yabai-dockstack/config.json` for anyone who prefers editing by hand.
- `debounceSeconds`: lower = snappier focus highlight, higher = fewer redraws
  during window drags.

- `style`: `"icon"` or `"flag"`. The menu-bar "Toggle icon/flag" item flips this
  and writes it back to the config file.
- `debounceSeconds`: minimum interval between redraws when events arrive in a
  burst.
- `pollSeconds`: low-frequency fallback refresh, in case a signal is missed.

Use **Reload config** in the menu after editing the file by hand.

## How it works

```
yabai window event ──▶ ~/.yabairc signal runs: yabai-dockstack --refresh
                                                    │ (pokes unix socket)
                                                    ▼
                       SignalListener ──▶ RefreshCoordinator (debounced)
                                                    │
                          yabai -m query --windows  ▼
                       StackBuilder ──▶ IndicatorLayout + CoordinateMapper
                                                    │
                                          OverlayRenderer (one NSPanel per stack)
```

A low-frequency timer also triggers a refresh as a safety net. Focusing a window
is delegated to `yabai -m window --focus`, so the app itself needs no
Accessibility permission.

## Testing

- **Toolchain-independent self-test** (works with Command Line Tools), covering
  decode, stack grouping, layout, coordinate mapping, config, diffing, and the
  socket round-trip:
  ```sh
  swift run yst-selftest
  ```
  Pass a captured query to exercise the live decode path:
  ```sh
  yabai -m query --windows > /tmp/q.json && swift run yst-selftest /tmp/q.json
  ```
- **Full XCTest suite** (requires Xcode):
  ```sh
  swift test
  ```
- **Replay mode** — render indicators from a static JSON dump without live yabai,
  for visual checks:
  ```sh
  .build/debug/yabai-dockstack --replay Tests/YabaiDockstackKitTests/Fixtures/query-sample.json
  ```

## Acceptance checklist

1. `./scripts/bundle.sh` produces `yabai-dockstack.app`.
2. `open yabai-dockstack.app` → a `▦` item appears in the menu bar; the menu shows
   **yabai: connected ✓** (signals were auto-registered — verify with
   `yabai -m signal --list | grep yabai-dockstack`).
3. Create a stack: `yabai -m window --stack next`.
5. Icons appear beside the stacked window, top→bottom in stack order; the focused
   window's icon is brightest.
6. Hover an icon → a tooltip shows that window's title (multiple VSCode windows
   show distinct project names).
7. Click a non-focused icon → that window comes to front; highlight updates.
8. Menu bar → **Toggle icon/flag** switches appearance and persists it.
9. On a second display, indicators appear correctly placed on that screen.
10. LaunchAgent makes it start at login.

## Dock window previews

Hover a **Dock app icon** to pop up that app's windows across all spaces; click one
to jump to its space and focus it (like a Windows-taskbar peek / DockView).

- **Thumbnails:** a live thumbnail is shown for windows on a currently-visible
  space. For windows on **other spaces** macOS cannot produce a live image
  (verified: ScreenCaptureKit returns `-3811` for off-screen windows), so the app
  shows the **last cached thumbnail** (captured while the window was on-screen) or,
  if none, the **app icon + title**. Either way the entry is clickable.
- **Permissions:** this feature needs **Accessibility** (to detect the hovered
  Dock icon) and **Screen Recording** (to capture thumbnails). You'll be prompted
  on first enable; grant both in System Settings → Privacy & Security. If a
  permission is missing the feature stays dormant — the core stack indicators need
  no permissions at all.
- **Toggle:** Settings → **Dock window previews** (on by default).

## App icon

The icon lives in `assets/`. Two variants are generated from
`assets/icon-source.png`:

- `AppIcon-native.icns` — content padded on a transparent canvas with rounded
  corners (macOS HIG style). **This is the bundled default** (`AppIcon.icns`).
- `AppIcon-fullbleed.icns` — the source as-is, square corners.

See `assets/icon-preview.png` for a side-by-side. To switch the bundled icon to
full-bleed, copy `assets/AppIcon-fullbleed.icns` over `assets/AppIcon.icns` and
rebuild. To regenerate everything after editing the source:

```sh
python3 scripts/make-icons.py   # requires Pillow + macOS iconutil
```

> Note: the name/logo use "yabai". This is an **unofficial** community tool and is
> not affiliated with the yabai project.

## License

MIT.
