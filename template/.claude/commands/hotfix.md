---
description: Speed-first fix for an urgent breakage — single agent, no plan ceremony, board Status only
argument-hint: [issue-number-or-description]
---

# Hotfix: Ship the Fix Fast

## Target

$ARGUMENTS

## When to use

Production-impacting breakage where speed beats ceremony: something is broken *now* and the fix path is clear. No plan file, no PRD lookup, no subagents — one agent, smallest correct fix, out the door.

**Escalate if unclear:** if the root cause isn't obvious after a fast diagnosis, run `/plan-hotfix` first to pin it down — or `/bug` if a proper failing-test-first fix is warranted.

## Step 0: Link the issue (if one exists)

If the argument is (or references) an existing GitHub issue:

- Read the issue body: `gh issue view <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}}`
- Move the board item to "In Progress": `./.claude/scripts/move-issue.sh <NUMBER> "In Progress"`
- Claim the issue for this session: `./.claude/scripts/claim-issue.sh <NUMBER> claim` (auto-detects the worktree; `main` in the main checkout). On `CLAIM COLLISION` (exit 3), stop and ask the user.

**Status only — a hotfix never sets the Phase field.** (The script above only touches Status; never pass a phase anywhere.)

If no issue exists, skip this step entirely; **do not create one** — issue ceremony is exactly what a hotfix sheds.

**Never close issues or move them to Done here — closing happens at the ship
step (`/commit` on the default branch, `/merge`, or a merged PR).**

## Step 1: Diagnose fast

Read the failure (error output, logs, the reported symptom) and find the smallest correct fix. Read only the directly implicated files.

Deviation rules at this weight:

1. **Fix bugs inline** — if the diagnosis surfaces an adjacent bug in the same code path, fixing it in the same change is OK.
2. **Add validation at boundaries** — if the breakage came through an unguarded boundary (user input, API response), guarding it is part of the fix.
3. **Architecture changes → STOP.** If completing the fix would require changing the project's architecture, adding new dependencies, restructuring the database schema, or altering auth/middleware behavior, STOP and ask before proceeding. A hotfix that needs architecture is not a hotfix.

## Step 2: Fix + prove it

Apply the fix. Then demonstrate the broken behavior is gone with **one targeted validation** — re-run the failing command, hit the broken endpoint, reproduce the original symptom. Not the full suite: the per-turn battery still fires at turn end regardless (see workflow.md § Hook Layer).

## Step 3: Hand off

Report what was broken, what changed, and the proof it's fixed. Then run `/commit`:

- The commit tag MUST be `fix:` — `hotfix` is not a Conventional Commits type.
- Leave the issue open; **closing happens at the ship step** (`/commit` on the default branch — the usual hotfix case — or `/merge` / a merged PR for branch work).
