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
  build

mkdir -p build/dmg-root
ditto \
  .derivedData-release/Build/Products/Release/OpencodeWidgetApp.app \
  build/dmg-root/OpencodeWidgetApp.app
ln -s /Applications build/dmg-root/Applications
hdiutil create \
  -volname "OpencodeWidgetApp" \
  -srcfolder build/dmg-root \
  -ov \
  -format UDZO \
  build/OpencodeWidgetApp.dmg
