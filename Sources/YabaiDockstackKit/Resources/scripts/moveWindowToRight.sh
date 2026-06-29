#!/bin/sh
inputAction=$1

case $inputAction in
'display')
  yabai -m window --display next --focus 2>/dev/null || yabai -m window --display first --focus
  ;;
'space')
  sh "$(dirname "$0")/moveWindowOnDisplaySpace.sh" next
  ;;
*)
  wid=$(yabai -m query --windows --window | jq -re '.id')
  sh "$(dirname "$0")/moveWindowToSpace.sh" "$wid" "$inputAction"
  ;;
esac
