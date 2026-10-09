#!/bin/bash
# Build a release binary and wrap it in an .app bundle (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")"
CONFIG="${1:-release}"
APP="build/Speed Editor Bridge.app"
swift build -c "$CONFIG" --product SpeedEditorBridge
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/$CONFIG/SpeedEditorBridge" "$APP/Contents/MacOS/Speed Editor Bridge"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>Speed Editor Bridge</string>
    <key>CFBundleIdentifier</key><string>church.fbcld.speed-editor-bridge</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>Speed Editor Bridge</string>
    <key>CFBundleDisplayName</key><string>Speed Editor Bridge</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>First Baptist Church Lake Dallas</string>
</dict>
</plist>
PLIST
IDENTITY="Speed Editor Bridge Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  echo "No '$IDENTITY' certificate; signing ad hoc (Accessibility must be re-granted after each build). Run tools/make-signing-cert.sh once to fix."
  codesign --force --sign - "$APP"
fi
echo "Built $APP"
