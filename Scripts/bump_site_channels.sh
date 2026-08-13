#!/usr/bin/env bash
# Promote channels after a new GitHub release:
#   previous beta  → stable
#   NEW version    → beta
# Top-level version.json fields mirror stable (in-app update checker).
#
# Usage:
#   Scripts/bump_site_channels.sh 1.1.4 "Short release notes."
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JSON="${ROOT}/docs/version.json"
NEW_VERSION="${1:-}"
NOTES="${2:-}"

if [[ -z "${NEW_VERSION}" ]]; then
  echo "Usage: $0 <new-version> [notes]" >&2
  exit 1
fi

NEW_VERSION="$NEW_VERSION" NOTES="$NOTES" JSON="$JSON" python3 - <<'PY'
import json, os
from pathlib import Path

path = Path(os.environ["JSON"])
new_version = os.environ["NEW_VERSION"]
notes = os.environ.get("NOTES", "")

data = json.loads(path.read_text())
prev_beta = data.get("beta") or data.get("stable") or {
    "version": data.get("version"),
    "tag": data.get("tag"),
    "dmg": data.get("dmg"),
    "release": data.get("release"),
    "notes": data.get("notes", ""),
}

def entry(version, notes_text):
    tag = f"v{version}"
    return {
        "version": version,
        "tag": tag,
        "dmg": f"https://github.com/linux503/MacText/releases/download/{tag}/MacText-{version}.dmg",
        "release": f"https://github.com/linux503/MacText/releases/tag/{tag}",
        "notes": notes_text,
    }

stable = prev_beta
beta = entry(new_version, notes or f"MacText {new_version} beta.")

out = {
    "stable": stable,
    "beta": beta,
    "version": stable["version"],
    "tag": stable["tag"],
    "dmg": stable["dmg"],
    "release": stable["release"],
    "notes": stable.get("notes", ""),
}
path.write_text(json.dumps(out, indent=2) + "\n")
print(f"stable={stable['version']}  beta={beta['version']}")
print(f"wrote {path}")
PY
