---
description: Fix a reported bug with a failing-test-first workflow — issue body as context
argument-hint: [issue-number]
---

# Bug: Reproduce, Then Fix

## Target

Issue: $ARGUMENTS

## Step 0: Pull the context

The issue is the repro source — read all of it, including discussion:

- `gh issue view <NUMBER> --repo nicholasmartin/claude-workflow-template --comments`
- Move the board item to "In Progress": `./.claude/scripts/move-issue.sh <NUMBER> "In Progress"`

Extract from the issue: the observed behavior, the expected behavior, repro steps if given, and any logs/stack traces in the body or comments.

**Never close issues or move them to Done here — only `/commit` closes issues.**

## Step 1: Reproduce first (the contract of this command)

Before touching the fix: **make the bug happen on demand.**

- **If the project has a test framework:** write a failing test that captures the bug. As Fowler puts it, replicate the bug with a test — the test ensures the bug stays dead.
- **If the project has no test framework:** reproduce manually and record the exact repro steps plus observed-vs-expected as a comment on the issue (`gh issue comment <NUMBER> --repo nicholasmartin/claude-workflow-template --body "..."`). The template is language-agnostic — a recorded manual repro is a first-class path, not a fallback failure.

**Do not proceed to Step 2 until you have a red repro** — a failing test or a documented, repeatable manual reproduction. If you cannot reproduce it, stop and report what you tried; a fix without a repro is a guess.

## Step 2: Fix

Make the smallest change that turns the repro green. Deviation rules:

1. **Fix bugs inline** — adjacent bugs in the same code path may be fixed in the same change; note them.
2. **Add validation at boundaries** — if the bug entered through an unguarded boundary, the guard is part of the fix.
3. **Fix blockers pragmatically** — if the fix can't land as first envisioned (missing helper, wrong assumption about the code), take the simplest working alternative and document it.
4. **Architecture changes → STOP.** If completing the fix would require changing the project's architecture, adding new dependencies, restructuring the database schema, or altering auth/middleware behavior, STOP and ask before proceeding.

## Step 3: Prove the death

- The failing test from Step 1 now passes (or the manual repro no longer reproduces — re-run the recorded steps).
- Run one targeted validation around the touched code (the affected module's tests, the relevant lint). The per-turn battery still fires at turn end regardless (see workflow.md § Hook Layer).

## Step 4: Close-out

- Check off any acceptance criteria in the issue body that the fix satisfies (`gh issue edit <NUMBER> --repo nicholasmartin/claude-workflow-template --body "<updated body>"`)
- Comment the repro + fix summary: what reproduced it, root cause (file:line), what changed, proof it's dead
- **Leave the issue OPEN** — only `/commit` closes issues.
- Hand off to `/commit` with a `fix:` tag.
