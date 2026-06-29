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
# Copy SwiftPM resource bundle into Contents/Resources so Bundle.module resolves
# via Bundle.main.resourceURL at runtime. Keep its original structure intact.
for bundle in .build/release/*YabaiDockstackKit.bundle; do
    [ -d "$bundle" ] || continue
    rm -rf "$APP/Contents/Resources/$(basename "$bundle")"
    cp -R "$bundle" "$APP/Contents/Resources/"
done
# Ad-hoc code sign so macOS lets the Accessibility/Screen-Recording toggles stick
# (fully-unsigned apps often can't be granted reliably). Sign last (after Info.plist).
codesign --force --deep --sign - --identifier com.yabai-dockstack.agent "$APP"
echo "Built $APP"
echo "Absolute path: $(pwd)/$APP/Contents/MacOS/yabai-dockstack"
