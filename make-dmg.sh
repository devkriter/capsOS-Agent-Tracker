#!/bin/bash
# Builds a drag-to-install disk image (CapsLockLED.dmg): open it and drag
# CapsLockLED onto the Applications shortcut. Run ./build.sh first (this
# script will run it for you if the app isn't built yet).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="CapsLockLED"
VOL_NAME="CapsLockLED"
APP_DIR="$SCRIPT_DIR/$APP_NAME.app"
DIST_DIR="$SCRIPT_DIR/dist"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
STAGING="$(mktemp -d)"
TMP_DMG="$(mktemp -u).dmg"

if [ ! -d "$APP_DIR" ]; then
    echo "App not built yet — running build.sh..."
    "$SCRIPT_DIR/build.sh"
fi

echo "Staging disk image contents..."
mkdir -p "$STAGING"
cp -R "$APP_DIR" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

cat > "$STAGING/Read Me First.txt" <<'TXT'
CapsLockLED — quick start
=========================

1. Drag "CapsLockLED" onto the "Applications" folder in this window.

2. Open Applications, then RIGHT-CLICK CapsLockLED and choose "Open".
   (Do this the first time only. Because the app isn't from the App Store,
   a normal double-click may be blocked — right-click → Open gets past it.)

3. A small circle icon appears in the menu bar (top-right of your screen).
   If you use a menu-bar organiser like Barbee or Bartender, it may hide the
   icon — reveal hidden icons and drag CapsLockLED into the visible area.

4. The first time it runs, macOS will ask for "Input Monitoring" permission
   (this is what lets the app control the Caps Lock light — it does NOT read
   your typing). Turn CapsLockLED on in that list, then quit and reopen it.

5. Click the menu bar icon → "Set Up Claude Code Hooks". Done!
   Start a new Claude Code session and the Caps Lock light will:
     • slow-blink while Claude is working
     • fast-blink when Claude needs your input
     • double-flash when Claude finishes

Tip: click the icon → "Launch at Login" so it's always running.

Full guide: see the README in the project, or the project page.
TXT

echo "Creating read-write image..."
rm -f "$TMP_DMG"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGING" -fs HFS+ \
    -format UDRW -ov "$TMP_DMG" >/dev/null

echo "Applying window layout (non-fatal if it fails)..."
MOUNT_DIR="/Volumes/$VOL_NAME"
hdiutil attach "$TMP_DMG" -noautoopen -quiet || true
if [ -d "$MOUNT_DIR" ]; then
    osascript <<APPLESCRIPT || echo "  (layout step skipped)"
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 720, 460}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set position of item "$APP_NAME.app" of container window to {130, 150}
        set position of item "Applications" of container window to {390, 150}
        set position of item "Read Me First.txt" of container window to {260, 300}
        update without registering applications
        close
    end tell
end tell
APPLESCRIPT
    sync
    hdiutil detach "$MOUNT_DIR" -quiet || true
fi

echo "Converting to compressed read-only image..."
mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"
hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG_PATH" >/dev/null
rm -f "$TMP_DMG"
rm -rf "$STAGING"

echo ""
echo "Built: $DMG_PATH"
ls -lh "$DMG_PATH"
