#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="Nibiko"
DISPLAY_NAME="Nibiko"
PACKAGE_DIR="$ROOT_DIR/.build/package"
APP_DIR="$PACKAGE_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$ROOT_DIR/Packaging/Nibiko/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Packaging/Nibiko/Nibiko.entitlements"
ICON_FILE="$ROOT_DIR/Packaging/Nibiko/Nibiko.icns"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
DMG_PATH="${DMG_PATH:-$OUTPUT_DIR/$APP_NAME-$VERSION.dmg}"
STAGING_DIR="$PACKAGE_DIR/dmg-staging"
MOUNT_DIR="$PACKAGE_DIR/dmg-mount"

cleanup_mount() {
  if mount | grep -q "on $MOUNT_DIR "; then
    hdiutil detach "$MOUNT_DIR" -quiet || true
  fi
}

trap cleanup_mount EXIT

swift build -c "$CONFIGURATION" --product "$APP_NAME"
BUILD_BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP_DIR" "$STAGING_DIR" "$MOUNT_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp -X "$BUILD_BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp -X "$INFO_PLIST" "$CONTENTS_DIR/Info.plist"
cp -X "$ICON_FILE" "$RESOURCES_DIR/Nibiko.icns"

plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null
xattr -cr "$APP_DIR" || true

codesign_args=(--force --sign "$CODESIGN_IDENTITY" --entitlements "$ENTITLEMENTS")
if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
  codesign_args+=(--options runtime --timestamp)
fi
codesign "${codesign_args[@]}" "$APP_DIR"
codesign --verify --strict --verbose=2 "$APP_DIR"

if ! spctl -a -vv --type execute "$APP_DIR"; then
  printf '%s\n' "warning: Gatekeeper will reject this build unless it is signed with Developer ID and notarized." >&2
fi

mkdir -p "$OUTPUT_DIR" "$STAGING_DIR" "$MOUNT_DIR"
ditto --noextattr --noqtn "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$DISPLAY_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MOUNT_DIR" "$DMG_PATH"
test -d "$MOUNT_DIR/$APP_NAME.app"
hdiutil detach "$MOUNT_DIR" -quiet

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

printf 'app: %s\n' "$APP_DIR"
printf 'dmg: %s\n' "$DMG_PATH"
printf 'version: %s (%s)\n' "$VERSION" "$BUILD_NUMBER"
