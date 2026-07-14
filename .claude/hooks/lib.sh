#!/usr/bin/env bash
# Shared helpers for Claude Code hook scripts.
#
# Contracts every hook in this directory relies on:
#   - Hooks receive JSON on stdin and run from the LAUNCH directory, not
#     the project root. Always resolve paths via $PROJECT_DIR.
#   - stdin can only be read once: call hook_read_stdin first, then
#     extract fields from $HOOK_INPUT with hook_field.
#   - JSON parsing uses jq when installed, else python3. If neither
#     exists, extractors return empty — hooks must treat empty as
#     "no-op silently" and NEVER block on missing tooling.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Read all of stdin into $HOOK_INPUT. Safe on empty/absent stdin.
hook_read_stdin() {
  HOOK_INPUT="$(cat 2>/dev/null || true)"
}

# hook_field <dotted.path> — print the field value from $HOOK_INPUT.
# Booleans print as "true"/"false"; missing paths print nothing.
hook_field() {
  local path="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$HOOK_INPUT" | jq -r "if .${path} == null then empty else (.${path} | tostring) end" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$HOOK_INPUT" | python3 -c '
import json, sys
try:
    obj = json.load(sys.stdin)
    for key in sys.argv[1].split("."):
        obj = obj[key]
    if obj is True:
        print("true")
    elif obj is False:
        print("false")
    elif obj is not None:
        print(obj)
except Exception:
    pass
' "$path" 2>/dev/null
  fi
}

# has_node_tool <bin> — true only when this is an npm project AND the
# binary resolves locally (no network installs, no global surprises).
has_node_tool() {
  [ -f "$PROJECT_DIR/package.json" ] || return 1
  (cd "$PROJECT_DIR" && npx --no-install "$1" --version >/dev/null 2>&1)
}
