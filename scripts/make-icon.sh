#!/usr/bin/env bash
# Renders the app icon and converts it to .icns. Usage: scripts/make-icon.sh <output.icns>
set -euo pipefail

OUTPUT="$1"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swift "$(dirname "$0")/make-icon.swift" "$WORK/icon-1024.png"

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUTPUT"
echo "Wrote $OUTPUT"
