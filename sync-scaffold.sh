#!/bin/bash
# Sync the scaffold's validated .claude config into a project.
# Usage: ./sync-scaffold.sh /path/to/project
# Copies CLAUDE.md + agents/, verifies byte-identical, reports (but never
# overwrites) settings.json drift — permissions are often project-specific.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/.claude"
PROJECT="${1:?usage: sync-scaffold.sh /path/to/project}"
DST="$PROJECT/.claude"
[ -d "$DST" ] || { echo "error: no .claude directory in $PROJECT" >&2; exit 1; }

cp "$SRC/CLAUDE.md" "$DST/CLAUDE.md"
mkdir -p "$DST/agents"
cp "$SRC"/agents/*.md "$DST/agents/"

fail=0
cmp -s "$SRC/CLAUDE.md" "$DST/CLAUDE.md" || fail=1
for f in "$SRC"/agents/*.md; do
  cmp -s "$f" "$DST/agents/$(basename "$f")" || fail=1
done
if [ "$fail" -ne 0 ]; then
  echo "VERIFY FAILED: copied files do not match source" >&2
  exit 1
fi
echo "synced + verified byte-identical: CLAUDE.md, $(ls "$SRC/agents" | wc -l | tr -d ' ') agents -> $DST"

if ! cmp -s "$SRC/settings.json" "$DST/settings.json" 2>/dev/null; then
  echo ""
  echo "note: $DST/settings.json differs from the scaffold's (NOT overwritten — review manually):"
  diff "$SRC/settings.json" "$DST/settings.json" || true
fi

echo ""
echo "reminder: rerun the agent canary in the project before trusting delegation."
