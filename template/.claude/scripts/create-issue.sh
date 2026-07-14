#!/usr/bin/env bash
# create-issue.sh --title T --body-file F [--labels "a,b"]
#                 [--phase "Phase N"] [--priority P] [--status S] [--parent N]
#
# The canonical issue-creation path (workflow.md §6): creates the issue,
# applies labels, adds it to the project board, sets Status/Priority/Phase
# fields, and optionally links it as a sub-issue of a parent epic.
# Prints: "<number> <url>"
#
# Status/Priority option IDs are baked in at sync time; Phase options are
# resolved by name at runtime (phases get added as projects grow).
#
# NOTE: the template copy contains unfilled placeholder tokens and is not
# runnable; only the synced project copy is.
set -euo pipefail

TITLE="" BODY_FILE="" LABELS="" PHASE="" PRIORITY="" STATUS="Backlog" PARENT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --title)     TITLE="$2";     shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --labels)    LABELS="$2";    shift 2 ;;
    --phase)     PHASE="$2";     shift 2 ;;
    --priority)  PRIORITY="$2";  shift 2 ;;
    --status)    STATUS="$2";    shift 2 ;;
    --parent)    PARENT="$2";    shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done
if [ -z "$TITLE" ] || [ -z "$BODY_FILE" ] || [ ! -f "$BODY_FILE" ]; then
  echo 'usage: create-issue.sh --title T --body-file F [--labels "a,b"] [--phase "Phase N"] [--priority P] [--status S] [--parent N]' >&2
  exit 1
fi

status_opt() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    backlog)       echo "{{STATUS_BACKLOG_ID}}" ;;
    ready)         echo "{{STATUS_READY_ID}}" ;;
    "in progress") echo "{{STATUS_IN_PROGRESS_ID}}" ;;
    done)          echo "{{STATUS_DONE_ID}}" ;;
  esac
}
priority_opt() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    low)      echo "{{PRIORITY_LOW_ID}}" ;;
    medium)   echo "{{PRIORITY_MEDIUM_ID}}" ;;
    high)     echo "{{PRIORITY_HIGH_ID}}" ;;
    critical) echo "{{PRIORITY_CRITICAL_ID}}" ;;
  esac
}

# 1. Create the issue (labels applied at creation)
URL="$(gh issue create --repo {{REPO_OWNER}}/{{REPO_NAME}} \
  --title "$TITLE" --body-file "$BODY_FILE" ${LABELS:+--label "$LABELS"})"
NUM="${URL##*/}"

# 2. Node ID + add to board
ISSUE_ID="$(gh api graphql -f query="query { repository(owner: \"{{REPO_OWNER}}\", name: \"{{REPO_NAME}}\") { issue(number: $NUM) { id } } }" \
  --jq '.data.repository.issue.id')"
ITEM_ID="$(gh api graphql -f query="mutation { addProjectV2ItemById(input: { projectId: \"{{PROJECT_ID}}\", contentId: \"$ISSUE_ID\" }) { item { id } } }" \
  --jq '.data.addProjectV2ItemById.item.id')"

# 3. Build one mutation for all requested fields
MUTS=""
S_OPT="$(status_opt "$STATUS")"
[ -n "$S_OPT" ] && MUTS="$MUTS s: updateProjectV2ItemFieldValue(input: { projectId: \"{{PROJECT_ID}}\", itemId: \"$ITEM_ID\", fieldId: \"{{STATUS_FIELD_ID}}\", value: { singleSelectOptionId: \"$S_OPT\" } }) { projectV2Item { id } }"

if [ -n "$PRIORITY" ]; then
  P_OPT="$(priority_opt "$PRIORITY")"
  [ -n "$P_OPT" ] && MUTS="$MUTS p: updateProjectV2ItemFieldValue(input: { projectId: \"{{PROJECT_ID}}\", itemId: \"$ITEM_ID\", fieldId: \"{{PRIORITY_FIELD_ID}}\", value: { singleSelectOptionId: \"$P_OPT\" } }) { projectV2Item { id } }"
fi

if [ -n "$PHASE" ]; then
  PH_OPT="$(gh project field-list {{PROJECT_NUMBER}} --owner @me --format json \
    --jq ".fields[] | select(.name == \"Phase\") | .options[] | select(.name == \"$PHASE\") | .id")"
  if [ -n "$PH_OPT" ]; then
    MUTS="$MUTS ph: updateProjectV2ItemFieldValue(input: { projectId: \"{{PROJECT_ID}}\", itemId: \"$ITEM_ID\", fieldId: \"{{PHASE_FIELD_ID}}\", value: { singleSelectOptionId: \"$PH_OPT\" } }) { projectV2Item { id } }"
  else
    echo "warning: Phase option \"$PHASE\" not found on the board — field not set" >&2
  fi
fi

[ -n "$MUTS" ] && gh api graphql -f query="mutation { $MUTS }" >/dev/null

# 4. Optional: link under a parent epic
if [ -n "$PARENT" ]; then
  PARENT_ID="$(gh api graphql -f query="query { repository(owner: \"{{REPO_OWNER}}\", name: \"{{REPO_NAME}}\") { issue(number: $PARENT) { id } } }" \
    --jq '.data.repository.issue.id')"
  gh api graphql -f query="mutation { addSubIssue(input: { issueId: \"$PARENT_ID\", subIssueId: \"$ISSUE_ID\" }) { issue { number } } }" >/dev/null
fi

echo "$NUM $URL"
