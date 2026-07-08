#!/bin/bash
# Legacy copy-mode sync: push the scaffold's validated config into a project
# that does NOT use the sdd-scaffold plugin. Plugin installs are preferred —
# see README. Usage: ./sync-scaffold.sh /path/to/project
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT="${1:?usage: sync-scaffold.sh /path/to/project}"
DST="$PROJECT/.claude"
[ -d "$DST" ] || { echo "error: no .claude directory in $PROJECT" >&2; exit 1; }

# CLAUDE.md = the orchestrator skill body, minus its YAML frontmatter
awk 'f; /^---$/{c++; if(c==2) f=1}' "$ROOT/skills/sdd-orchestrator/SKILL.md" \
  | sed '1{/^$/d;}' > "$DST/CLAUDE.md"
mkdir -p "$DST/agents"
cp "$ROOT"/agents/*.md "$DST/agents/"

fail=0
for f in "$ROOT"/agents/*.md; do
  cmp -s "$f" "$DST/agents/$(basename "$f")" || fail=1
done
grep -q "Orchestrator Instructions" "$DST/CLAUDE.md" || fail=1
if [ "$fail" -ne 0 ]; then
  echo "VERIFY FAILED: synced files do not match source" >&2
  exit 1
fi
echo "synced + verified: CLAUDE.md, $(ls "$ROOT/agents" | wc -l | tr -d ' ') agents -> $DST"

if ! cmp -s "$ROOT/.claude/settings.json" "$DST/settings.json" 2>/dev/null; then
  echo ""
  echo "note: $DST/settings.json differs from the scaffold's (NOT overwritten — review manually):"
  diff "$ROOT/.claude/settings.json" "$DST/settings.json" || true
fi

echo ""
echo "reminder: rerun the agent canary in the project before trusting delegation."
