#!/usr/bin/env bash
# Dump the full work-tracking state as one JSON blob:
#   { "issues": [...open...], "closed": [...recent...], "board": {...} }
# Used by /continue and /status via inline bash so the data is in
# context before the agent starts analyzing.
#
# NOTE: the template copy contains unfilled placeholder tokens and is not
# runnable; only the synced project copy is.
set -euo pipefail

ISSUES="$(gh issue list --repo nicholasmartin/claude-workflow-template --state open --json number,title,labels,state --limit 50)"
CLOSED="$(gh issue list --repo nicholasmartin/claude-workflow-template --state closed --json number,title,closedAt --limit 10)"
BOARD="$(gh project item-list 18 --owner @me --format json)"

printf '{"issues":%s,"closed":%s,"board":%s}\n' "$ISSUES" "$CLOSED" "$BOARD"
