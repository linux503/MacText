#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==== MacText release ===="
bash "${ROOT}/Scripts/make_icon.sh"
bash "${ROOT}/Scripts/build_app.sh"
bash "${ROOT}/Scripts/make_dmg.sh"
echo "==== Release complete ===="
ls -lh dist/*.app dist/*.dmg dist/*.sha256 2>/dev/null || true
echo ""
echo "Next: create GitHub release, then promote site channels:"
echo "  Scripts/bump_site_channels.sh <NEW_VERSION> \"notes\""
echo "  (previous beta → stable, new version → beta)"
