#!/usr/bin/env bash
# Sync the template (source of truth) into this repo's live installation.
#
#   template/.claude  ->  .claude   (placeholders filled from scripts/workflow.env)
#   template/.agents  ->  .agents   (only files that don't already exist)
#
# Rules:
#   - template/ is ALWAYS edited first; never edit .claude/ copies directly.
#   - init-project.md is copied verbatim: its {{...}} braces are instructional.
#   - Files that exist only in .claude/ (CLAUDE.md, PRD.md, plans) are untouched.
set -euo pipefail
cd "$(dirname "$0")/.."

source scripts/workflow.env

# Guard: root-only files must never exist in (or ship from) template/.
# validate-local.sh is this repo's private battery — if it leaked into
# template/, every template user would inherit repo-specific checks, and
# copying it would clobber the real root file (possibly mid-execution).
for private in .claude/hooks/validate-local.sh; do
  if [[ -e "template/$private" ]]; then
    echo "ERROR: template/$private is root-only and must never ship. Delete it from template/." >&2
    exit 1
  fi
done

mapfile -t files < <(cd template/.claude && find . -type f | sort)

for rel in "${files[@]}"; do
  src="template/.claude/$rel"
  dst=".claude/$rel"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"

  # init-project.md keeps its placeholders (generic setup instructions)
  [[ "$rel" == *"init-project.md"* ]] && continue

  sed -i \
    -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
    -e "s|{{REPO_OWNER}}|$REPO_OWNER|g" \
    -e "s|{{REPO_NAME}}|$REPO_NAME|g" \
    -e "s|{{PROJECT_NUMBER}}|$PROJECT_NUMBER|g" \
    -e "s|{{PROJECT_ID}}|$PROJECT_ID|g" \
    -e "s|{{STATUS_FIELD_ID}}|$STATUS_FIELD_ID|g" \
    -e "s|{{STATUS_BACKLOG_ID}}|$STATUS_BACKLOG_ID|g" \
    -e "s|{{STATUS_READY_ID}}|$STATUS_READY_ID|g" \
    -e "s|{{STATUS_IN_PROGRESS_ID}}|$STATUS_IN_PROGRESS_ID|g" \
    -e "s|{{STATUS_DONE_ID}}|$STATUS_DONE_ID|g" \
    -e "s|{{PHASE_FIELD_ID}}|$PHASE_FIELD_ID|g" \
    -e "s|{{PRIORITY_FIELD_ID}}|$PRIORITY_FIELD_ID|g" \
    -e "s|{{PRIORITY_LOW_ID}}|$PRIORITY_LOW_ID|g" \
    -e "s|{{PRIORITY_MEDIUM_ID}}|$PRIORITY_MEDIUM_ID|g" \
    -e "s|{{PRIORITY_HIGH_ID}}|$PRIORITY_HIGH_ID|g" \
    -e "s|{{PRIORITY_CRITICAL_ID}}|$PRIORITY_CRITICAL_ID|g" \
    -e "s|(populated as phases are created)|$PHASE_OPTIONS|g" \
    "$dst"
done

# Hook and plumbing scripts must stay executable after copy
chmod +x .claude/hooks/*.sh .claude/scripts/*.sh 2>/dev/null || true

# .agents: copy only missing files (never clobber real plans)
(cd template/.agents && find . -type f) | while read -r rel; do
  dst=".agents/$rel"
  if [[ ! -f "$dst" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp "template/.agents/$rel" "$dst"
  fi
done

# Verify: no unresolved {{TOKEN}} placeholders in the files we generated.
# Only generated files are checked — root-only files (PRD.md, hooks
# extensions) may legitimately mention placeholder syntax. init-project.md
# keeps its instructional braces by design.
leftover=""
for rel in "${files[@]}"; do
  [[ "$rel" == *"init-project.md"* ]] && continue
  if grep -qE '\{\{[A-Z_]+\}\}' ".claude/$rel" 2>/dev/null; then
    leftover="${leftover}.claude/$rel"$'\n'
  fi
done
if [[ -n "$leftover" ]]; then
  echo "ERROR: unresolved placeholders in:" >&2
  printf '%s' "$leftover" >&2
  exit 1
fi
echo "OK: template synced, all placeholders resolved."
