#!/usr/bin/env bash
# Add to ~/.yabairc (adjust BIN to the built binary path printed by scripts/bundle.sh).
BIN="$HOME/Project/stackline/yabai-stackline.app/Contents/MacOS/yabai-stackline"
for evt in window_focused window_moved window_resized window_created \
           window_destroyed space_changed display_changed application_front_switched; do
  yabai -m signal --add event="$evt" action="$BIN --refresh"
done
