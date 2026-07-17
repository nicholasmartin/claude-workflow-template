#!/usr/bin/env bash
# move-issue.sh <issue-number> <status>
# Moves a board item to a Status column. Replaces the three-step
# item-ID / field-ID / option-ID choreography with one call.
#
# NOTE: the template copy contains unfilled placeholder tokens and is not
# runnable; only the synced project copy is.
set -euo pipefail

usage() {
  echo "usage: move-issue.sh <issue-number> <Backlog|Ready|\"In Progress\"|\"In Review\"|Done>" >&2
  exit 1
}
[ $# -eq 2 ] || usage
NUM="$1"

case "$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" in
  backlog)       OPT="{{STATUS_BACKLOG_ID}}" ;;
  ready)         OPT="{{STATUS_READY_ID}}" ;;
  "in progress") OPT="{{STATUS_IN_PROGRESS_ID}}" ;;
  "in review")   OPT="{{STATUS_IN_REVIEW_ID}}" ;;
  done)          OPT="{{STATUS_DONE_ID}}" ;;
  *) usage ;;
esac

ITEM_ID="$(gh project item-list {{PROJECT_NUMBER}} --owner @me --format json --limit 200 \
  --jq ".items[] | select(.content.number == $NUM) | .id")"
if [ -z "$ITEM_ID" ]; then
  echo "error: issue #$NUM is not on project board #{{PROJECT_NUMBER}}" >&2
  exit 1
fi

gh project item-edit --project-id {{PROJECT_ID}} --id "$ITEM_ID" \
  --field-id {{STATUS_FIELD_ID}} --single-select-option-id "$OPT" >/dev/null
echo "issue #$NUM -> $2"
