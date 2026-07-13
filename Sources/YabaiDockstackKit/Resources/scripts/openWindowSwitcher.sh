#!/bin/sh
# Ask the running yabai-dockstack app to open the window switcher (sticky mode).
sock=$(jq -r '.socketPath // empty' "$HOME/.config/yabai-dockstack/config.json" 2>/dev/null)
[ -n "$sock" ] || sock=/tmp/yabai-dockstack.sock
printf 'show-switcher\n' | /usr/bin/nc -U -w 2 "$sock" 2>/dev/null || true
