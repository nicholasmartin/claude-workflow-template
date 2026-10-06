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

# Look up this one issue's board item, not the whole board: `gh project
# item-list` pulls every item with every field value, and a run of moves
# trips GitHub's secondary (burst) rate limit. Its --limit also silently
# missed items once the board outgrew it.
ITEM_ID="$(gh api graphql \
  -f query='query($n: Int!) { repository(owner: "{{REPO_OWNER}}", name: "{{REPO_NAME}}") {
    issue(number: $n) { projectItems(first: 20) { nodes { id project { id } } } } } }' \
  -F n="$NUM" \
  --jq '.data.repository.issue.projectItems.nodes[] | select(.project.id == "{{PROJECT_ID}}") | .id')" \
  || { echo "error: could not look up issue #$NUM (see the gh error above)" >&2; exit 1; }
if [ -z "$ITEM_ID" ]; then
  echo "error: issue #$NUM is not on project board #{{PROJECT_NUMBER}}" >&2
  exit 1
fi

gh project item-edit --project-id {{PROJECT_ID}} --id "$ITEM_ID" \
  --field-id {{STATUS_FIELD_ID}} --single-select-option-id "$OPT" >/dev/null
echo "issue #$NUM -> $2"
