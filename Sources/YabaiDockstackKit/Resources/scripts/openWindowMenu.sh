#!/bin/sh
# Ask the running yabai-dockstack app to open its window menu (menu bar).
sock=$(jq -r '.socketPath // empty' "$HOME/.config/yabai-dockstack/config.json" 2>/dev/null)
[ -n "$sock" ] || sock=/tmp/yabai-dockstack.sock
printf 'show-menu\n' | /usr/bin/nc -U -w 2 "$sock" 2>/dev/null || true
