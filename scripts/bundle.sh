#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="yabai-stackline.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/yabai-stackline "$APP/Contents/MacOS/yabai-stackline"
cp scripts/Info.plist.template "$APP/Contents/Info.plist"
echo "Built $APP"
echo "Absolute path: $(pwd)/$APP/Contents/MacOS/yabai-stackline"
