#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo "=== 1. Building FrameLabMac in Release Mode ==="
swift build -c release --target FrameLabMac

BIN_PATH="${ROOT_DIR}/.build/out/Products/Release/FrameLabMac"
if [ ! -f "${BIN_PATH}" ]; then
    BIN_PATH=$(swift build -c release --show-bin-path)/FrameLabMac
fi

echo "=== 2. Assembling FrameLab.app Bundle ==="
APP_BUNDLE="${ROOT_DIR}/dist/dmg_root/FrameLab.app"
rm -rf "${ROOT_DIR}/dist" "${ROOT_DIR}/FrameLab.dmg"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/FrameLabMac"

if [ -f "${ROOT_DIR}/AppIcon.icns" ]; then
    cp "${ROOT_DIR}/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

cat << 'EOF' > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FrameLabMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.framelab.app</string>
    <key>CFBundleName</key>
    <string>FrameLab</string>
    <key>CFBundleDisplayName</key>
    <string>FrameLab</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

printf "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "=== 3. Code Signing App Bundle ==="
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "=== 4. Creating Applications Symlink ==="
ln -s /Applications "${ROOT_DIR}/dist/dmg_root/Applications"

echo "=== 5. Packaging FrameLab.dmg ==="
hdiutil create -volname "FrameLab" -srcfolder "${ROOT_DIR}/dist/dmg_root" -ov -format UDZO "${ROOT_DIR}/FrameLab.dmg"

echo "=== Done! Created FrameLab.dmg at ${ROOT_DIR}/FrameLab.dmg ==="
