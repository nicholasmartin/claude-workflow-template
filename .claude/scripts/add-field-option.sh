#!/usr/bin/env bash
# add-field-option.sh <field-name> <option-name> [--color COLOR] [--desc TEXT]
# Safely appends one option to a single-select project field (e.g. minting
# "Phase 7" as a project grows). Prints the option's ID.
#
# WHY THIS SCRIPT EXISTS: the GraphQL updateProjectV2Field mutation REPLACES
# the field's entire option list — omitting an existing option deletes it and
# clears that value from every board item. This script makes the operation
# safe by construction: it rebuilds the array from a live read taken
# immediately before the mutation (every existing option re-sent verbatim
# WITH its id), and only ever APPENDS. It never reorders, renames, or removes
# options — use the GitHub UI for that. Never hand-write a
# singleSelectOptions mutation against a board that has items.
#
# Idempotent: if <option-name> already exists, prints its id and exits 0.
# Limitation: option names/descriptions must not contain double quotes or
# backslashes (plumbing simplicity, matches this workflow's naming).
#
# NOTE: the template copy contains unfilled placeholder tokens and is not
# runnable; only the synced project copy is.
set -euo pipefail

usage() {
  echo 'usage: add-field-option.sh <field-name> <option-name> [--color GRAY|BLUE|GREEN|YELLOW|ORANGE|RED|PINK|PURPLE] [--desc TEXT]' >&2
  exit 1
}
[ $# -ge 2 ] || usage
FIELD_NAME="$1"; OPT_NAME="$2"; shift 2
COLOR="GRAY"; DESC=""
while [ $# -gt 0 ]; do
  case "$1" in
    --color) COLOR="$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')"; shift 2 ;;
    --desc)  DESC="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done
case "$COLOR" in
  GRAY|BLUE|GREEN|YELLOW|ORANGE|RED|PINK|PURPLE) ;;
  *) echo "error: invalid color '$COLOR'" >&2; usage ;;
esac
case "$OPT_NAME$DESC" in
  *'"'*|*'\'*) echo 'error: option name/description must not contain " or \' >&2; exit 1 ;;
esac

# 1. Resolve the field id by name
FIELD_ID="$(gh project field-list 18 --owner @me --format json \
  --jq ".fields[] | select(.name == \"$FIELD_NAME\") | .id")"
if [ -z "$FIELD_ID" ]; then
  echo "error: field \"$FIELD_NAME\" not found on project #18" >&2
  exit 1
fi

READ_QUERY="query { node(id: \"$FIELD_ID\") { ... on ProjectV2SingleSelectField { options { id name color description } } } }"

# 2. Idempotency: option already exists -> print its id, done
EXISTING_ID="$(gh api graphql -f query="$READ_QUERY" \
  --jq ".data.node.options[]? | select(.name == \"$OPT_NAME\") | .id")"
if [ -n "$EXISTING_ID" ]; then
  echo "$EXISTING_ID"
  exit 0
fi

# 3. Rebuild the option list from the live read: every existing option
#    re-sent verbatim WITH its id (this is what preserves board item values),
#    serialized straight from the API response — never from env or memory.
EXISTING_GQL="$(gh api graphql -f query="$READ_QUERY" \
  --jq '.data.node.options | map("{id: " + (.id | @json) + ", name: " + (.name | @json) + ", color: " + .color + ", description: " + ((.description // "") | @json) + "}") | join(", ")')"
if [ -z "$EXISTING_GQL" ]; then
  echo "error: field \"$FIELD_NAME\" has no readable options — not a single-select field? Refusing to mutate." >&2
  exit 1
fi

# 4. Append the new option (no id -> created) and mutate
NEW_OPT="{name: \"$OPT_NAME\", color: $COLOR, description: \"$DESC\"}"
NEW_ID="$(gh api graphql -f query="mutation { updateProjectV2Field(input: { fieldId: \"$FIELD_ID\", singleSelectOptions: [ $EXISTING_GQL, $NEW_OPT ] }) { projectV2Field { ... on ProjectV2SingleSelectField { options { id name } } } } }" \
  --jq ".data.updateProjectV2Field.projectV2Field.options[] | select(.name == \"$OPT_NAME\") | .id")"
if [ -z "$NEW_ID" ]; then
  echo "error: mutation returned no id for \"$OPT_NAME\" — inspect the field in the UI before retrying" >&2
  exit 1
fi
echo "$NEW_ID"
