#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP_NAME="MacText"
DIST="$ROOT/dist"
APP="$DIST/${APP_NAME}.app"
CONTENTS="${APP}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
TMP="${ROOT}/.build/universal-staging"
BUILD_ARM="${ROOT}/.build/arm64"
BUILD_X86="${ROOT}/.build/x86_64"

echo "==> Ensuring app icon..."
bash "${ROOT}/Scripts/make_icon.sh"

rm -rf "${TMP}" "${BUILD_ARM}" "${BUILD_X86}"
mkdir -p "${TMP}" "${BUILD_ARM}" "${BUILD_X86}"

find_binary() {
  local root="$1"
  local candidate="${root}/${CONFIG}/${APP_NAME}"
  if [ -f "${candidate}" ]; then
    echo "${candidate}"
    return 0
  fi
  find "${root}" -type f -name "${APP_NAME}" | while read -r path; do
    if [ -x "${path}" ]; then
      echo "${path}"
      break
    fi
  done
}

echo "==> Building arm64..."
swift build -c "${CONFIG}" --arch arm64 --build-path "${BUILD_ARM}"
ARM_BIN="$(find_binary "${BUILD_ARM}")"
echo "    arm64 binary: ${ARM_BIN}"
test -n "${ARM_BIN}"
test -f "${ARM_BIN}"
file "${ARM_BIN}"
cp "${ARM_BIN}" "${TMP}/MacText-arm64"

echo "==> Building x86_64 Intel..."
swift build -c "${CONFIG}" --arch x86_64 --build-path "${BUILD_X86}"
X86_BIN="$(find_binary "${BUILD_X86}")"
echo "    x86_64 binary: ${X86_BIN}"
test -n "${X86_BIN}"
test -f "${X86_BIN}"
file "${X86_BIN}"
cp "${X86_BIN}" "${TMP}/MacText-x86_64"

ARM_ARCHS="$(lipo -archs "${TMP}/MacText-arm64")"
X86_ARCHS="$(lipo -archs "${TMP}/MacText-x86_64")"
echo "    staged arches: ${ARM_ARCHS} / ${X86_ARCHS}"

echo "${ARM_ARCHS}" | grep -q arm64
echo "${X86_ARCHS}" | grep -q x86_64

UNIVERSAL="${TMP}/MacText-universal"
lipo -create "${TMP}/MacText-arm64" "${TMP}/MacText-x86_64" -output "${UNIVERSAL}"
echo "==> Universal binary:"
file "${UNIVERSAL}"
lipo -info "${UNIVERSAL}"

echo "==> Assembling app bundle..."
rm -rf "${APP}"
mkdir -p "${MACOS}" "${RESOURCES}"
mkdir -p "${CONTENTS}/SharedSupport/bin"
cp "${UNIVERSAL}" "${MACOS}/${APP_NAME}"
cp "${ROOT}/Resources/Info.plist" "${CONTENTS}/Info.plist"
cp "${ROOT}/Resources/AppIcon.icns" "${RESOURCES}/AppIcon.icns"
cp "${ROOT}/Resources/MacTextIcon.png" "${RESOURCES}/MacTextIcon.png"
cp "${ROOT}/Resources/mactext-cli" "${CONTENTS}/SharedSupport/bin/mactext"
chmod +x "${MACOS}/${APP_NAME}"
chmod +x "${CONTENTS}/SharedSupport/bin/mactext"
printf 'APPL????' > "${CONTENTS}/PkgInfo"

echo "==> Ad-hoc codesign..."
codesign --force --deep --sign - "${APP}" >/dev/null 2>&1 || true

# Register with Launch Services so Finder / Git clients can discover us as an editor.
if command -v lsregister >/dev/null 2>&1; then
  lsregister -f "${APP}" >/dev/null 2>&1 || true
elif [ -x /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister ]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${APP}" >/dev/null 2>&1 || true
fi

echo "==> Done: ${APP}"
echo "    Architectures: $(lipo -archs "${MACOS}/${APP_NAME}")"
echo "    CLI: ${CONTENTS}/SharedSupport/bin/mactext"
echo "    Run: open \"${APP}\""
