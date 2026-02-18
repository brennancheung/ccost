#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Building CCostBar..."
swift build -c release

APP_DIR=".build/release/CCostBar.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS"

cp .build/release/CCostBar "$MACOS/CCostBar"

cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CCostBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.brennan.ccostbar</string>
    <key>CFBundleName</key>
    <string>CCostBar</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST

echo "Built: $APP_DIR"
