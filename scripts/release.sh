#!/usr/bin/env bash
# Build a universal (arm64 + x86_64) .app, zip it for a GitHub Release, and print
# the sha256 to paste into the Homebrew cask.
# Usage: scripts/release.sh [version]   e.g. scripts/release.sh 0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-0.1.0}"
APP="yabai-dockstack.app"

# Prefer a universal build (needs full Xcode); fall back to native arch (CLT).
swift build -c release --arch arm64 --arch x86_64 || swift build -c release
BIN=".build/apple/Products/Release/yabai-dockstack"
[ -f "$BIN" ] || BIN=".build/release/yabai-dockstack"   # fallback (single-arch)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/yabai-dockstack"
cp scripts/Info.plist.template "$APP/Contents/Info.plist"
[ -f assets/AppIcon.icns ] && cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
[ -f assets/menubar.png ] && cp assets/menubar.png "$APP/Contents/Resources/menubar.png"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"

ZIP="yabai-dockstack-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Built $ZIP"
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/yabai-dockstack" 2>/dev/null || echo unknown)"
echo "sha256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo
echo "Next:"
echo "  gh release create v$VERSION $ZIP --title v$VERSION --notes '...'"
echo "  then put the sha256 + version into your Homebrew cask (dist/yabai-dockstack.rb)."
