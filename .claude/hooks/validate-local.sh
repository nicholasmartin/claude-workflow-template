#!/usr/bin/env bash
# ROOT-ONLY — this file is NOT part of template/ and is never touched by
# sync-template.sh. It is this repo's Stop-hook battery, run by
# .claude/hooks/stop-validate.sh. It checks the template-repo's own
# invariants. Exit non-zero on any failure; stdout/stderr become the
# agent's fix instructions.

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}" || exit 1
FAIL=0

# --- 1. Root-only files must never leak into the shipped template ------
# MUST run before anything invokes sync: a same-named file in template/
# would otherwise be copied over this very script while it executes
# (bash reads scripts lazily — self-clobber kills the battery silently).
# sync-template.sh carries the same guard as the primary defense.
for private in validate-local.sh; do
  if [ -e "template/.claude/hooks/$private" ]; then
    echo "Boundary violation: template/.claude/hooks/$private exists — this file is root-only and must never ship. Delete it from template/ before anything else runs."
    exit 1
  fi
done

# --- 2. No unresolved {{TOKEN}} placeholders in GENERATED files --------
# Only files with a counterpart in template/.claude are checked: root-only
# files (PRD.md, this script) may legitimately mention placeholder syntax.
LEFT=""
while IFS= read -r rel; do
  case "$rel" in *init-project.md*) continue ;; esac
  if grep -qE '\{\{[A-Z_]+\}\}' ".claude/${rel#./}" 2>/dev/null; then
    LEFT="${LEFT}.claude/${rel#./}
"
  fi
done < <(cd template/.claude && find . -type f)
if [ -n "$LEFT" ]; then
  echo "Unresolved {{placeholders}} in generated files:"
  printf '%s' "$LEFT"
  FAIL=1
fi

# --- 3. Template/root sync drift ---------------------------------------
# sync-template.sh is idempotent: if running it changes any file content
# under .claude/, the root copy was stale (someone edited template/
# without syncing, or hand-edited a generated root file).
snapshot() {
  find .claude -type f -print0 2>/dev/null | sort -z | xargs -0 sha1sum 2>/dev/null | sha1sum
}
PRE="$(snapshot)"
if ! ./scripts/sync-template.sh >/dev/null 2>&1; then
  echo "scripts/sync-template.sh failed — run it directly to see why."
  FAIL=1
else
  POST="$(snapshot)"
  if [ "$PRE" != "$POST" ]; then
    echo "Template/root drift: template/ was edited without syncing."
    echo "sync-template.sh has now regenerated the root copies — review with 'git status .claude' and stage the updated files."
    FAIL=1
  fi
fi

# --- 4. Shell syntax across the toolchain ------------------------------
for f in scripts/*.sh .claude/hooks/*.sh .claude/scripts/*.sh; do
  [ -f "$f" ] || continue
  if ! ERR="$(bash -n "$f" 2>&1)"; then
    echo "Shell syntax error in $f:"
    echo "$ERR"
    FAIL=1
  fi
done

exit $FAIL
