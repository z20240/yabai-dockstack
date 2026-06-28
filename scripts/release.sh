#!/usr/bin/env bash
# Build a universal (arm64 + x86_64) .app, zip it for a GitHub Release, and print
# the sha256 to paste into the Homebrew cask.
#
# Usage: scripts/release.sh [version]      e.g. scripts/release.sh 0.1.0
#
# Signing / notarization (all optional, via env vars):
#   DEVID           "Developer ID Application: Name (TEAMID)" — sign for
#                   distribution with the hardened runtime instead of ad-hoc.
#   NOTARY_PROFILE  notarytool keychain profile, created once with:
#                     xcrun notarytool store-credentials <profile> \
#                       --apple-id <id> --team-id <TEAMID> --password <app-specific-pw>
#   (or set NOTARY_APPLE_ID / NOTARY_TEAM_ID / NOTARY_PASSWORD instead of a profile)
#
# With none set (default): ad-hoc sign, no notarization (current behaviour; the
# Homebrew cask strips quarantine so it still opens). With DEVID + notary creds:
# Developer-ID sign + notarize + staple → opens with zero Gatekeeper friction.
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

# --- Sign (after Info.plist edits, which signing seals) ---
if [ -n "${DEVID:-}" ]; then
  echo "Signing with Developer ID (hardened runtime): $DEVID"
  codesign --force --deep --options runtime --timestamp \
           --sign "$DEVID" --identifier com.yabai-dockstack.agent "$APP"
else
  # Ad-hoc: lets the Accessibility/Screen-Recording toggles stick; not notarizable.
  echo "Ad-hoc signing (set DEVID to sign for distribution)"
  codesign --force --deep --sign - --identifier com.yabai-dockstack.agent "$APP"
fi

ZIP="yabai-dockstack-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# --- Notarize (optional; only when Developer-ID signed AND creds provided) ---
if [ -n "${DEVID:-}" ] && { [ -n "${NOTARY_PROFILE:-}" ] || [ -n "${NOTARY_APPLE_ID:-}" ]; }; then
  echo "Submitting for notarization (this can take a few minutes)…"
  if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  else
    xcrun notarytool submit "$ZIP" \
          --apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" \
          --password "$NOTARY_PASSWORD" --wait
  fi
  echo "Stapling the notarization ticket…"
  xcrun stapler staple "$APP"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"   # re-zip the stapled app
  echo "Notarized + stapled (no Gatekeeper prompt for users)."
else
  echo "Skipping notarization (set DEVID + NOTARY_PROFILE to enable)."
fi

echo "Built $ZIP"
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/yabai-dockstack" 2>/dev/null || echo unknown)"
echo "sha256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo
echo "Next:"
echo "  gh release create v$VERSION $ZIP --title v$VERSION --notes '...'"
echo "  then put the sha256 + version into your Homebrew cask (dist/yabai-dockstack.rb)."
