#!/usr/bin/env bash
set -euo pipefail

# Flush Launch Services + Dock icon caches for MacText after replacing the .app
APP="${1:-}"
if [ -z "${APP}" ]; then
  APP="$(cd "$(dirname "$0")/.." && pwd)/dist/MacText.app"
fi

if [ ! -d "${APP}" ]; then
  echo "App not found: ${APP}" >&2
  exit 1
fi

echo "==> Registering ${APP}"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${APP}"

echo "==> Touching bundle to invalidate caches"
touch "${APP}"
touch "${APP}/Contents/Info.plist"
touch "${APP}/Contents/Resources/AppIcon.icns"

echo "==> Clearing icon services caches (user)"
rm -rf "${HOME}/Library/Caches/com.apple.iconservices.store" 2>/dev/null || true
find "${HOME}/Library/Caches" -name 'com.apple.iconservices*' -maxdepth 2 -exec rm -rf {} + 2>/dev/null || true

echo "==> Restarting Dock / Finder icon helpers"
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
sleep 1

echo "==> Done. Re-open the app:"
echo "    open \"${APP}\""
