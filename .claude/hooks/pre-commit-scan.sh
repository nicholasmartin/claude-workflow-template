#!/usr/bin/env bash
# Ship-time WARN-tier scan of STAGED files.
#
# Invoked by /commit (and by .husky/pre-commit on JS projects, wired by
# /init-project). Prints findings as file:line: match and ALWAYS exits 0
# — the proceed/stop conversation is /commit's job, not this script's.
#
# Detects: placeholder markers, empty function bodies, empty catch
# blocks, and focused/skipped tests (.only / .skip) in test files.

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}" || exit 0

# Exclude this script (and its template copy) — its grep patterns would
# otherwise match themselves on every commit that ships the hooks.
SELF_FILTER='/hooks/pre-commit-scan\.sh$'
JS_STAGED="$(git diff --cached --name-only --diff-filter=ACM -- '*.ts' '*.tsx' '*.js' '*.jsx' 2>/dev/null | grep -vE "$SELF_FILTER" || true)"
CODE_STAGED="$(git diff --cached --name-only --diff-filter=ACM -- '*.ts' '*.tsx' '*.js' '*.jsx' '*.sh' '*.py' 2>/dev/null | grep -vE "$SELF_FILTER" || true)"

MATCHES=""
add_matches() {
  [ -n "$1" ] && MATCHES="${MATCHES}${1}
"
}

if [ -n "$CODE_STAGED" ]; then
  add_matches "$(printf '%s\n' "$CODE_STAGED" | xargs -r -d '\n' grep -nH -E '(TODO|FIXME|HACK|XXX)\b' 2>/dev/null)"
fi

if [ -n "$JS_STAGED" ]; then
  add_matches "$(printf '%s\n' "$JS_STAGED" | xargs -r -d '\n' grep -nH -E '(function[^{;]*|=>)\s*\{\s*\}' 2>/dev/null)"
  add_matches "$(printf '%s\n' "$JS_STAGED" | xargs -r -d '\n' grep -nH -E 'catch\s*(\([^)]*\))?\s*\{\s*\}' 2>/dev/null)"
  TEST_STAGED="$(printf '%s\n' "$JS_STAGED" | grep -E '(test|spec)' 2>/dev/null || true)"
  if [ -n "$TEST_STAGED" ]; then
    add_matches "$(printf '%s\n' "$TEST_STAGED" | xargs -r -d '\n' grep -nH -E '\.(only|skip)\(' 2>/dev/null)"
  fi
fi

if [ -n "$MATCHES" ]; then
  MATCHES="$(printf '%s' "$MATCHES" | grep . | sort -u)"
  COUNT="$(printf '%s\n' "$MATCHES" | grep -c .)"
  printf 'Placeholder scan: %s finding(s) in staged files\n' "$COUNT"
  printf '%s\n' "$MATCHES"
fi

exit 0
