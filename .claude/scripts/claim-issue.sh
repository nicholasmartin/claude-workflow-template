#!/usr/bin/env bash
# claim-issue.sh <issue-number> claim [<name>]
# claim-issue.sh <issue-number> release
#
# Session-ownership claims (Coordination Layer, workflow.md §10). A claim is a
# dynamic `worktree:<name>` label on the issue:
#   claim   — create the label idempotently, add it, then re-read the issue and
#             back off if another session claimed first (GitHub has no
#             compare-and-swap; exit 3 = collision, earliest claimant keeps it).
#             <name> defaults to the current worktree's slug, or "main" when
#             running in the main checkout.
#   release — remove every worktree:* label from the issue; delete each label
#             object no open issue still carries (keeps the label list clean).
#             Releasing an unclaimed issue is a no-op.
#
# NOTE: the template copy contains unfilled placeholder tokens and is not
# runnable; only the synced project copy is.
set -euo pipefail

usage() {
  echo "usage: claim-issue.sh <issue-number> claim [<name>]" >&2
  echo "       claim-issue.sh <issue-number> release" >&2
  exit 1
}
[ $# -ge 2 ] || usage
NUM="$1"
ACTION="$2"
case "$NUM" in *[!0-9]* | '') usage ;; esac

# Claim identity: worktree slug when under .claude/worktrees/<name>, else "main".
detect_name() {
  case "$PWD" in
    */.claude/worktrees/*) printf '%s' "${PWD##*/.claude/worktrees/}" | cut -d/ -f1 ;;
    *) printf 'main' ;;
  esac
}

worktree_labels() {
  gh issue view "$NUM" --repo nicholasmartin/claude-workflow-template --json labels \
    --jq '.labels[].name | select(startswith("worktree:"))'
}

# Delete a claim label's repo object if no open issue carries it anymore.
# The list index lags label removal by a moment — without the settle delay
# the just-released issue still counts and GC is skipped. Best-effort: a
# lagging index or vanished label must never fail a claim/release.
gc_label() {
  local OPEN D
  for D in 2 3; do
    sleep "$D"
    OPEN="$(gh issue list --repo nicholasmartin/claude-workflow-template --label "$1" --state open \
      --json number --jq 'length')"
    [ "$OPEN" -eq 0 ] && break
  done
  if [ "$OPEN" -eq 0 ]; then
    gh label delete "$1" --repo nicholasmartin/claude-workflow-template --yes >/dev/null 2>&1 \
      || echo "note: label $1 not deleted (in use or already gone)" >&2
  else
    echo "note: label $1 left in place (index still lists an open issue)" >&2
  fi
}

case "$ACTION" in
  claim)
    NAME="${3:-$(detect_name)}"
    LABEL="worktree:$NAME"
    # Labels must exist before --add-label; --force makes this idempotent.
    gh label create "$LABEL" --repo nicholasmartin/claude-workflow-template \
      --color "5319e7" --description "Session ownership claim" --force >/dev/null
    gh issue edit "$NUM" --repo nicholasmartin/claude-workflow-template --add-label "$LABEL" >/dev/null
    # No CAS on GitHub: verify after writing; later writer backs off.
    CLAIMS="$(worktree_labels)"
    COUNT="$(printf '%s\n' "$CLAIMS" | grep -c '^worktree:' || true)"
    if [ "$COUNT" -gt 1 ]; then
      gh issue edit "$NUM" --repo nicholasmartin/claude-workflow-template --remove-label "$LABEL" >/dev/null
      gc_label "$LABEL"
      OTHER="$(printf '%s\n' "$CLAIMS" | grep -vxF "$LABEL" | paste -sd' ' -)"
      echo "CLAIM COLLISION: issue #$NUM already claimed by $OTHER — pick different work." >&2
      exit 3
    fi
    echo "Claimed #$NUM for $LABEL"
    ;;
  release)
    CLAIMS="$(worktree_labels)"
    if [ -z "$CLAIMS" ]; then
      echo "issue #$NUM has no claim (no-op)"
      exit 0
    fi
    while IFS= read -r L; do
      gh issue edit "$NUM" --repo nicholasmartin/claude-workflow-template --remove-label "$L" >/dev/null
      gc_label "$L"
      echo "Released $L from #$NUM"
    done <<< "$CLAIMS"
    ;;
  *) usage ;;
esac
