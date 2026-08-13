#!/usr/bin/env bash
# Promote channels after a new GitHub release:
#   previous beta  → stable
#   NEW version    → beta
# Top-level version.json fields mirror stable (in-app update checker).
# Also prepends a stub entry to docs/changelog.json (edit en/zh highlights as needed).
#
# Usage:
#   Scripts/bump_site_channels.sh 1.1.4 "Short release notes."
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JSON="${ROOT}/docs/version.json"
CHANGELOG="${ROOT}/docs/changelog.json"
NEW_VERSION="${1:-}"
NOTES="${2:-}"

if [[ -z "${NEW_VERSION}" ]]; then
  echo "Usage: $0 <new-version> [notes]" >&2
  exit 1
fi

NEW_VERSION="$NEW_VERSION" NOTES="$NOTES" JSON="$JSON" CHANGELOG="$CHANGELOG" python3 - <<'PY'
import json, os
from datetime import date
from pathlib import Path

path = Path(os.environ["JSON"])
cl_path = Path(os.environ["CHANGELOG"])
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

# Prepend changelog stub
today = date.today().isoformat()
highlight = notes.strip() if notes.strip() else f"MacText {new_version}."
cl = {"updated": today, "entries": []}
if cl_path.exists():
    try:
        cl = json.loads(cl_path.read_text())
    except Exception:
        pass
entries = cl.get("entries") or []
# Relabel previous head beta → stable when promoting
if entries and entries[0].get("channel") == "beta" and entries[0].get("version") == stable.get("version"):
    entries[0]["channel"] = "stable"
stub = {
    "version": new_version,
    "date": today,
    "channel": "beta",
    "tag": f"v{new_version}",
    "en": {"title": f"MacText {new_version}", "highlights": [highlight]},
    "zh": {"title": f"MacText {new_version}", "highlights": [highlight]},
}
if not any(e.get("version") == new_version for e in entries):
    entries.insert(0, stub)
cl["updated"] = today
cl["entries"] = entries
cl_path.write_text(json.dumps(cl, indent=2, ensure_ascii=False) + "\n")
print(f"wrote {cl_path} (edit en/zh titles & highlights)")
PY
