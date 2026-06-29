#!/usr/bin/env bash
#
# Build Beam.app and package it into build/Beam.dmg for a GitHub release.
#
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/bundle.sh release

STAGE="$(mktemp -d)"
cp -R build/Beam.app "$STAGE/Beam.app"
ln -s /Applications "$STAGE/Applications"          # drag-to-install target

DMG="build/Beam.dmg"
rm -f "$DMG"
hdiutil create -volname "Beam" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "✓ Built $DMG ($(du -h "$DMG" | cut -f1))"
