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
  gh issue view "$NUM" --repo {{REPO_OWNER}}/{{REPO_NAME}} --json labels \
    --jq '.labels[].name | select(startswith("worktree:"))'
}

case "$ACTION" in
  claim)
    NAME="${3:-$(detect_name)}"
    LABEL="worktree:$NAME"
    # Labels must exist before --add-label; --force makes this idempotent.
    gh label create "$LABEL" --repo {{REPO_OWNER}}/{{REPO_NAME}} \
      --color "5319e7" --description "Session ownership claim" --force >/dev/null
    gh issue edit "$NUM" --repo {{REPO_OWNER}}/{{REPO_NAME}} --add-label "$LABEL" >/dev/null
    # No CAS on GitHub: verify after writing; later writer backs off.
    CLAIMS="$(worktree_labels)"
    COUNT="$(printf '%s\n' "$CLAIMS" | grep -c '^worktree:' || true)"
    if [ "$COUNT" -gt 1 ]; then
      gh issue edit "$NUM" --repo {{REPO_OWNER}}/{{REPO_NAME}} --remove-label "$LABEL" >/dev/null
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
      gh issue edit "$NUM" --repo {{REPO_OWNER}}/{{REPO_NAME}} --remove-label "$L" >/dev/null
      OPEN="$(gh issue list --repo {{REPO_OWNER}}/{{REPO_NAME}} --label "$L" --state open \
        --json number --jq 'length')"
      if [ "$OPEN" -eq 0 ]; then
        gh label delete "$L" --repo {{REPO_OWNER}}/{{REPO_NAME}} --yes >/dev/null
      fi
      echo "Released $L from #$NUM"
    done <<< "$CLAIMS"
    ;;
  *) usage ;;
esac
