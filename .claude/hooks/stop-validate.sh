#!/usr/bin/env bash
# Stop hook — per-turn BLOCKING validation battery.
#
# Tier contract (workflow.md § Hook Layer):
#   exit 0 = the turn may end
#   exit 2 = the turn is blocked; stderr becomes the agent's next
#            instruction ("fix this before finishing")
#
# Loop guard: when stop_hook_active is true, Claude is already
# continuing because this hook blocked once — exit 0 to avoid loops
# (Claude Code also force-overrides after 8 consecutive blocks).
#
# Budget: everything here must finish inside the hook timeout (120s).
# Test suites are NOT run by default — projects opt in via
# .claude/hooks/validate-local.sh (see workflow.md § Hook Layer).

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HOOK_DIR/lib.sh"

hook_read_stdin
[ "$(hook_field stop_hook_active)" = "true" ] && exit 0

FAILURES=""

# Cross-file typecheck (incremental: fast after the first run).
if [ -f "$PROJECT_DIR/tsconfig.json" ] && has_node_tool tsc; then
  if ! OUT="$(cd "$PROJECT_DIR" && npx --no-install tsc --noEmit --incremental 2>&1)"; then
    FAILURES="${FAILURES}--- tsc --noEmit ---
$(printf '%s\n' "$OUT" | head -30)
"
  fi
fi

# Project-defined battery (optional, root-only extension point).
if [ -x "$PROJECT_DIR/.claude/hooks/validate-local.sh" ]; then
  if ! OUT="$("$PROJECT_DIR/.claude/hooks/validate-local.sh" 2>&1)"; then
    FAILURES="${FAILURES}--- validate-local ---
$(printf '%s\n' "$OUT" | head -30)
"
  fi
fi

if [ -n "$FAILURES" ]; then
  printf 'Validation failed — fix before finishing:\n%s' "$FAILURES" >&2
  exit 2
fi

exit 0
