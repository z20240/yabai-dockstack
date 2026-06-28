#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="yabai-dockstack.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/yabai-dockstack "$APP/Contents/MacOS/yabai-dockstack"
cp scripts/Info.plist.template "$APP/Contents/Info.plist"
# App icon (default: native/padded). Swap to assets/AppIcon-fullbleed.icns if preferred.
[ -f assets/AppIcon.icns ] && cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
[ -f assets/menubar.png ] && cp assets/menubar.png "$APP/Contents/Resources/menubar.png"
echo "Built $APP"
echo "Absolute path: $(pwd)/$APP/Contents/MacOS/yabai-dockstack"
