#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="CapsLockLED"
BUNDLE_ID="com.furkansenturk.capslockled"
APP_DIR="$SCRIPT_DIR/$APP_NAME.app"

echo "Building release binaries..."
swift build -c release

BIN_DIR=".build/release"

echo "Assembling app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$BIN_DIR/caps-signal" "$APP_DIR/Contents/MacOS/caps-signal"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME" "$APP_DIR/Contents/MacOS/caps-signal"
cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Personal use.</string>
</dict>
</plist>
PLIST

SIGN_IDENTITY="CapsLockLED Dev"
if security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY"; then
    echo "Code signing with local identity: $SIGN_IDENTITY..."
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
else
    echo "Local signing identity not found, falling back to ad-hoc signing..."
    codesign --force --deep --sign - "$APP_DIR"
fi

echo ""
echo "Built: $APP_DIR"
echo "caps-signal path: $APP_DIR/Contents/MacOS/caps-signal"
