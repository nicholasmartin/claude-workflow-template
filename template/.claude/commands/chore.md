---
description: Ship a small maintenance task with minimum ceremony — no issue, no plan file
argument-hint: [task-description]
---

# Chore: Minimum-Ceremony Maintenance

## Task

$ARGUMENTS

## When to use

Typo fixes, dependency bumps, doc touch-ups, renames/moves — anything a reviewer would approve at a glance. This is the lightest rung of the executor ladder: no GitHub issue, no plan file, no board interaction, no subagents.

**Escalate if it grows:** if the "chore" turns out to involve a real bug, use `/bug`. If it needs design decisions or touches multiple components, stop and recommend `/plan-feature`. Do not let a chore silently become a feature.

## Step 1: Do the task

Make the change directly. Read the file(s) involved, apply the smallest correct edit, and keep to existing conventions.

**Deviation rule (the only one at this weight):** if the task reveals a real bug or a design question, STOP and tell the user which right-weight command fits (`/bug` for a bug, `/plan-feature` for anything needing design). Don't expand scope inside a chore.

## Step 2: Single validation pass

Run the narrowest check that proves the change is sound — e.g., the affected file's linter, a docs link check, or simply re-reading the diff for a docs-only change.

The per-turn validation battery is unskippable — the Stop hook fires it regardless of what you do here (see workflow.md § Hook Layer). This step only adds anything *task-specific* the battery wouldn't know about.

## Step 3: Hand off with a `chore:` commit

Tell the user the change is ready and run `/commit` when asked (or immediately if they said to ship it).

- The commit tag MUST be `chore:` — or `docs:` for pure documentation changes.
- No GitHub issue is created, linked, or closed for a chore — `/commit`'s issue step naturally no-ops when no open issues are affected.
