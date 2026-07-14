#!/usr/bin/env bash
# PostToolUse hook (matcher: Write|Edit) — per-edit ADVISORY lint.
#
# Tier contract (workflow.md § Hook Layer):
#   exit 0 = nothing to report
#   exit 2 = stderr is fed back to Claude as feedback. The edit already
#            happened; this never undoes or blocks it.
# Keep it fast: single-file checks only, silent skip for anything we
# have no checker for. Cross-file checks (tsc) belong to the Stop tier.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$HOOK_DIR/lib.sh"

hook_read_stdin
FILE="$(hook_field tool_input.file_path)"

# No path, or file vanished — nothing to check.
[ -n "$FILE" ] && [ -f "$FILE" ] || exit 0

case "$FILE" in
  *.sh)
    if ! ERR="$(bash -n "$FILE" 2>&1)"; then
      { printf 'Shell syntax check failed for %s:\n' "$FILE"
        printf '%s\n' "$ERR" | head -10; } >&2
      exit 2
    fi
    ;;
  *.ts|*.tsx|*.js|*.jsx)
    if has_node_tool eslint; then
      if ! ERR="$(cd "$PROJECT_DIR" && npx --no-install eslint --cache "$FILE" 2>&1)"; then
        { printf 'ESLint reported problems in %s:\n' "$FILE"
          printf '%s\n' "$ERR" | head -10; } >&2
        exit 2
      fi
    fi
    ;;
esac

exit 0
