# yabai-stackline

Visualize [yabai](https://github.com/koekeishiya/yabai) window stacks on macOS —
**without Hammerspoon**. A tiny native menu-bar agent that draws a floating
indicator next to each window stack so you can tell at a glance which apps are
in which stack and in what order, and **hover an indicator to see the window's
title** (e.g. which project each VSCode window is).

This is a clean Swift rewrite inspired by
[AdamWagner/stackline](https://github.com/AdamWagner/stackline) (which required
Hammerspoon). It is **not** a fork.

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

This produces `yabai-stackline.app` in the repo root and prints the absolute path
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

## Install

### 1. Tell yabai to poke the app on window events

Edit `examples/yabairc-signals.sh` so `BIN` points at the built binary, then add
its contents to your `~/.yabairc` (or source the script from there). It registers
yabai signals that call `yabai-stackline --refresh` — a one-liner that pokes the
running app over a Unix socket. After editing `~/.yabairc`:

```sh
yabai --restart-service
```

### 2. Auto-start at login (optional)

Edit `examples/com.yabai-stackline.agent.plist`, replacing
`REPLACE_WITH_ABSOLUTE_PATH` with the absolute path to the built binary, then:

```sh
cp examples/com.yabai-stackline.agent.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.yabai-stackline.agent.plist
```

Or just `open yabai-stackline.app` to run it once.

## Configuration

Optional config file at `~/.config/yabai-stackline/config.json`. Any omitted key
falls back to its default. All keys:

```json
{
  "yabaiPath": "/opt/homebrew/bin/yabai",
  "socketPath": "/tmp/yabai-stackline.sock",
  "style": "icon",
  "cellSize": 32,
  "offset": 4,
  "focusedAlpha": 1.0,
  "unfocusedAlpha": 0.4,
  "debounceSeconds": 0.3,
  "pollSeconds": 3.0
}
```

- `style`: `"icon"` or `"flag"`. The menu-bar "Toggle icon/flag" item flips this
  and writes it back to the config file.
- `debounceSeconds`: minimum interval between redraws when events arrive in a
  burst.
- `pollSeconds`: low-frequency fallback refresh, in case a signal is missed.

Use **Reload config** in the menu after editing the file by hand.

## How it works

```
yabai window event ──▶ ~/.yabairc signal runs: yabai-stackline --refresh
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
  .build/debug/yabai-stackline --replay Tests/YabaiStacklineKitTests/Fixtures/query-sample.json
  ```

## Acceptance checklist

1. `./scripts/bundle.sh` produces `yabai-stackline.app`.
2. `open yabai-stackline.app` → a `▦` item appears in the menu bar.
3. Add the yabai signals and restart yabai.
4. Create a stack: `yabai -m window --stack next`.
5. Icons appear beside the stacked window, top→bottom in stack order; the focused
   window's icon is brightest.
6. Hover an icon → a tooltip shows that window's title (multiple VSCode windows
   show distinct project names).
7. Click a non-focused icon → that window comes to front; highlight updates.
8. Menu bar → **Toggle icon/flag** switches appearance and persists it.
9. On a second display, indicators appear correctly placed on that screen.
10. LaunchAgent makes it start at login.

## License

MIT.
