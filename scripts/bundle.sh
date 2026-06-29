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
# Copy SwiftPM resource bundle next to the executable so Bundle.module resolves correctly.
# macOS 26 codesign rejects bundles that have a Resources/ subdirectory but no proper
# executable, so we restructure: promote Resources/* to the bundle root and add a
# minimal Info.plist + empty MacOS/ directory so codesign treats it as a signable BNDL.
for bundle in .build/release/*YabaiDockstackKit.bundle; do
    [ -d "$bundle" ] || continue
    bname="$(basename "$bundle" .bundle)"
    dest="$APP/Contents/MacOS/$(basename "$bundle")"
    mkdir -p "$dest/MacOS"
    # Promote Resources/* to the bundle root (avoids the Resources/ dir that breaks codesign)
    if [ -d "$bundle/Resources" ]; then
        cp -R "$bundle/Resources/." "$dest/"
    fi
    cat > "$dest/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${bname}</string>
    <key>CFBundleIdentifier</key>
    <string>com.yabai-dockstack.${bname}</string>
    <key>CFBundleName</key>
    <string>${bname}</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF
done
# Ad-hoc code sign so macOS lets the Accessibility/Screen-Recording toggles stick
# (fully-unsigned apps often can't be granted reliably). Sign last (after Info.plist).
codesign --force --deep --sign - --identifier com.yabai-dockstack.agent "$APP"
echo "Built $APP"
echo "Absolute path: $(pwd)/$APP/Contents/MacOS/yabai-dockstack"
