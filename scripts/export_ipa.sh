#!/usr/bin/env bash
set -euo pipefail

echo "============================================="
echo "      FrameLab iOS IPA Export Script         "
echo "============================================="

WORKSPACE="FrameLab.xcworkspace"
SCHEME="FrameLabIOS"
ARCHIVE_PATH="./build/FrameLabIOS.xcarchive"
EXPORT_PATH="./dist/ios"
PLIST_PATH="./scripts/exportOptions.plist"

mkdir -p ./build
mkdir -p ""

echo "1. Archiving FrameLabIOS..."
xcodebuild archive   -workspace ""   -scheme ""   -configuration Release   -destination 'generic/platform=iOS'   -archivePath ""

echo "2. Exporting .ipa package..."
xcodebuild -exportArchive   -archivePath ""   -exportOptionsPlist ""   -exportPath ""

echo "============================================="
echo " SUCCESS: IPA exported to "
echo "============================================="
