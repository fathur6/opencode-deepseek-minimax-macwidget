#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

VERSION="$(sed -n 's/.*MARKETING_VERSION: *"\{0,1\}\([0-9][0-9.]*\)"\{0,1\}.*/\1/p' project.yml | head -1)"
if [ -z "$VERSION" ]; then
  echo "error: could not read MARKETING_VERSION from project.yml" >&2
  exit 1
fi

# Invocation-owned staging and DerivedData so pre-existing build directories
# (including .derivedData-release) are never deleted or reused.
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/opencode-widget-dmg.XXXXXX")"
DERIVED_DATA="$STAGE/DerivedData"
DMG_ROOT="$STAGE/dmg-root"
trap 'rm -rf "$STAGE"' EXIT

xcodegen generate
xcodebuild \
  -project OpencodeWidgetApp.xcodeproj \
  -scheme OpencodeWidgetApp \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$DERIVED_DATA/Build/Products/Release/OpencodeWidgetApp.app"
mkdir -p "$DMG_ROOT"
ditto "$APP" "$DMG_ROOT/OpencodeWidgetApp.app"

# Strip folder-sync extended attributes (stamped by the synced parent directory)
# that codesign rejects, then sign ad-hoc. Without this, CodeSign fails with
# "resource fork, Finder information, or similar detritus not allowed".
xattr -dr com.apple.FinderInfo "$DMG_ROOT/OpencodeWidgetApp.app" 2>/dev/null || true
xattr -dr com.apple.fileprovider.fpfs#P "$DMG_ROOT/OpencodeWidgetApp.app" 2>/dev/null || true
codesign --force --deep --sign - "$DMG_ROOT/OpencodeWidgetApp.app"

ln -s /Applications "$DMG_ROOT/Applications"
STAGED_DMG="$STAGE/OpencodeWidget-$VERSION.dmg"
hdiutil create \
  -volname "OpencodeWidgetApp" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$STAGED_DMG"

# Never overwrite an existing published artifact.
mkdir -p build
OUTPUT="build/OpencodeWidget-$VERSION.dmg"
if [ -e "$OUTPUT" ]; then
  OUTPUT="build/OpencodeWidget-$VERSION-$(date +%Y%m%d%H%M%S).dmg"
fi
cp "$STAGED_DMG" "$OUTPUT"
echo "$OUTPUT"
