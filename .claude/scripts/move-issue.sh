#!/usr/bin/env bash
# move-issue.sh <issue-number> <status>
# Moves a board item to a Status column. Replaces the three-step
# item-ID / field-ID / option-ID choreography with one call.
#
# NOTE: the template copy contains unfilled placeholder tokens and is not
# runnable; only the synced project copy is.
set -euo pipefail

usage() {
  echo "usage: move-issue.sh <issue-number> <Backlog|Ready|\"In Progress\"|Done>" >&2
  exit 1
}
[ $# -eq 2 ] || usage
NUM="$1"

case "$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" in
  backlog)       OPT="5bc12968" ;;
  ready)         OPT="99ecc1d7" ;;
  "in progress") OPT="0e4738bd" ;;
  done)          OPT="43f67a5a" ;;
  *) usage ;;
esac

ITEM_ID="$(gh project item-list 18 --owner @me --format json \
  --jq ".items[] | select(.content.number == $NUM) | .id")"
if [ -z "$ITEM_ID" ]; then
  echo "error: issue #$NUM is not on project board #18" >&2
  exit 1
fi

gh project item-edit --project-id PVT_kwHOAC3aXM4BdVs6 --id "$ITEM_ID" \
  --field-id PVTSSF_lAHOAC3aXM4BdVs6zhX37pk --single-select-option-id "$OPT" >/dev/null
echo "issue #$NUM -> $2"
