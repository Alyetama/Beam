#!/usr/bin/env bash
#
# Build Beam.app from the SwiftPM package.
#   ./scripts/bundle.sh           # release build
#   ./scripts/bundle.sh debug     # debug build
#
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
echo "▸ Building Beam ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
APP="$PWD/build/Beam.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/Beam" "$APP/Contents/MacOS/Beam"
cp scripts/Info.plist "$APP/Contents/Info.plist"
if [ -f scripts/AppIcon.icns ]; then
    cp scripts/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc code signature so macOS lets the app open windows and use the network.
codesign --force --sign - "$APP" >/dev/null 2>&1 || \
    echo "  (codesign skipped — app will still run)"

echo "✓ Built $APP"
echo "  Open with:  open \"$APP\""
