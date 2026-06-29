#!/bin/sh
inputAction=$1

case $inputAction in
'display')
  yabai -m window --display prev --focus 2>/dev/null || yabai -m window --display last --focus
  ;;
'space')
  sh "$(dirname "$0")/moveWindowOnDisplaySpace.sh" prev
  ;;
*)
  wid=$(yabai -m query --windows --window | jq -re '.id')
  sh "$(dirname "$0")/moveWindowToSpace.sh" "$wid" "$inputAction"
  ;;
esac
