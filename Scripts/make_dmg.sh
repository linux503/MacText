#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="MacText"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist 2>/dev/null || echo 1.0.0)"
DIST="${ROOT}/dist"
APP="${DIST}/${APP_NAME}.app"
DMG_ROOT="${DIST}/dmg-root"
DMG_RW="${DIST}/${APP_NAME}-rw.dmg"
DMG_OUT="${DIST}/${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="MacText"

if [ ! -d "${APP}" ]; then
  echo "App not found. Building first..."
  bash "${ROOT}/Scripts/build_app.sh"
fi

echo "==> Preparing DMG contents..."
rm -rf "${DMG_ROOT}" "${DMG_RW}" "${DMG_OUT}"
mkdir -p "${DMG_ROOT}"
cp -R "${APP}" "${DMG_ROOT}/${APP_NAME}.app"
ln -s /Applications "${DMG_ROOT}/Applications"

# Optional background / readme
cat > "${DMG_ROOT}/README.txt" <<EOF
MacText ${VERSION}
=================

1. Drag MacText into Applications
2. Open from Launchpad or Applications
3. If Gatekeeper blocks: System Settings → Privacy & Security → Open Anyway

Universal Binary: Apple Silicon + Intel
EOF

echo "==> Creating temporary DMG..."
hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${DMG_ROOT}" \
  -ov \
  -format UDRW \
  "${DMG_RW}" >/dev/null

echo "==> Mounting and styling layout..."
MOUNT_DIR="$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_RW}" | awk '/\/Volumes\//{print $3; exit}')"
if [ -z "${MOUNT_DIR}" ]; then
  # Fallback parse
  MOUNT_DIR="/Volumes/${VOLUME_NAME}"
fi

# Wait for mount
for i in 1 2 3 4 5 6 7 8 9 10; do
  if [ -d "${MOUNT_DIR}" ]; then break; fi
  sleep 0.3
done

# Finder layout via AppleScript (best-effort)
osascript <<APPLESCRIPT || true
tell application "Finder"
  tell disk "${VOLUME_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 780, 480}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set position of item "${APP_NAME}.app" of container window to {140, 180}
    set position of item "Applications" of container window to {420, 180}
    set position of item "README.txt" of container window to {280, 340}
    update without registering applications
    delay 0.5
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "${MOUNT_DIR}" >/dev/null || hdiutil detach "/Volumes/${VOLUME_NAME}" -force >/dev/null || true

echo "==> Compressing final DMG..."
hdiutil convert "${DMG_RW}" -format UDZO -imagekey zlib-level=9 -o "${DMG_OUT}" >/dev/null
rm -f "${DMG_RW}"
rm -rf "${DMG_ROOT}"

# checksum
shasum -a 256 "${DMG_OUT}" > "${DMG_OUT}.sha256"

echo "==> Done"
ls -lh "${DMG_OUT}" "${DMG_OUT}.sha256"
echo "    Open: open \"${DMG_OUT}\""
