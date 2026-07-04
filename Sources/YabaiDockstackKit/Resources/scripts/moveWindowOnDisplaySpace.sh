#!/bin/sh
# Move focused window to prev/next space on the same display, following focus.
# With the scripting addition (SIP partially disabled) this uses yabai directly.
# Without it, the yabai-dockstack app simulates the native drag + ctrl+arrow
# gesture over its command socket (SIP-free).

direction=$1

sa_available() {
  # Only a fully-enabled SIP ("...status: enabled.") rules the SA out;
  # partial disables print "(Custom Configuration)" and don't match the
  # anchored pattern. If csrutil itself fails, assume no SA — the app
  # path always works, the yabai path silently no-ops without the SA.
  status=$(/usr/bin/csrutil status 2>/dev/null) || return 1
  [ -n "$status" ] || return 1
  ! printf '%s\n' "$status" | grep -q 'status: enabled\.$'
}

notify_app() {
  sock=$(jq -r '.socketPath // empty' "$HOME/.config/yabai-dockstack/config.json" 2>/dev/null)
  [ -n "$sock" ] || sock=/tmp/yabai-dockstack.sock
  printf 'move-space %s\n' "$1" | /usr/bin/nc -U -w 2 "$sock" 2>/dev/null || true
}

if ! sa_available; then
  notify_app "$direction"
  exit 0
fi

window=$(yabai -m query --windows --window)
wid=$(echo "$window" | jq -re '.id')
cur_display=$(echo "$window" | jq -re '.display')
cur_space=$(echo "$window" | jq -re '.space')

target=$(
  yabai -m query --spaces | jq -re --arg dir "$direction" --argjson display "$cur_display" --argjson cur "$cur_space" '
    [.[] | select(.display == $display) | .index] | sort | . as $spaces |
    ($spaces | index($cur)) as $i |
    if $dir == "next" then
      if $i == ($spaces | length - 1) then $spaces[0] else $spaces[$i + 1] end
    else
      if $i == 0 then $spaces[-1] else $spaces[$i - 1] end
    end
  '
)

sh "$(dirname "$0")/moveWindowToSpace.sh" "$wid" "$target"
