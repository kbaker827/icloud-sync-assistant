#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel) iCloud Sync Assistant.app and zips it.
# Usage: scripts/package-app.sh [version]   (defaults to the VERSION file)
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(tr -d '[:space:]' < VERSION)}"
VERSION="${VERSION#v}"
BUILD_NUMBER="${GITHUB_RUN_NUMBER:-1}"
APP_NAME="iCloud Sync Assistant"
EXECUTABLE="iCloudSyncAssistant"
DIST="dist"
APP="$DIST/$APP_NAME.app"
ZIP="$DIST/iCloud-Sync-Assistant-$VERSION.zip"
BUILD_FLAGS=(-c release --arch arm64 --arch x86_64 -Xswiftc -warnings-as-errors)

echo "==> Building $APP_NAME $VERSION ($BUILD_NUMBER)"
swift build "${BUILD_FLAGS[@]}"
BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"

echo "==> Making icon"
scripts/make-icon.sh "$APP/Contents/Resources/AppIcon.icns"

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"
codesign --verify --strict --verbose=2 "$APP"
lipo -info "$APP/Contents/MacOS/$EXECUTABLE"

echo "==> Zipping"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
echo "Created $ZIP"
