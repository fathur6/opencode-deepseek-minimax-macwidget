#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
rm -rf .derivedData-release build/dmg-root build/OpencodeWidgetApp.dmg
xcodegen generate
xcodebuild \
  -project OpencodeWidgetApp.xcodeproj \
  -scheme OpencodeWidgetApp \
  -configuration Release \
  -derivedDataPath .derivedData-release \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p build/dmg-root
ditto \
  .derivedData-release/Build/Products/Release/OpencodeWidgetApp.app \
  build/dmg-root/OpencodeWidgetApp.app

# Strip folder-sync extended attributes (stamped by the synced parent directory)
# that codesign rejects, then sign ad-hoc. Without this, CodeSign fails with
# "resource fork, Finder information, or similar detritus not allowed".
xattr -dr com.apple.FinderInfo build/dmg-root/OpencodeWidgetApp.app 2>/dev/null || true
xattr -dr com.apple.fileprovider.fpfs#P build/dmg-root/OpencodeWidgetApp.app 2>/dev/null || true
codesign --force --deep --sign - build/dmg-root/OpencodeWidgetApp.app

ln -s /Applications build/dmg-root/Applications
hdiutil create \
  -volname "OpencodeWidgetApp" \
  -srcfolder build/dmg-root \
  -ov \
  -format UDZO \
  build/OpencodeWidgetApp.dmg
