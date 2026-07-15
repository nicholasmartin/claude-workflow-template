---
description: Minimal bug-fix plan from repro and logs — failing-test-first task order
argument-hint: [issue-number]
---

# Plan Bug: Repro → Root Cause → Fix Plan

## Target

Issue: $ARGUMENTS

## When to use

A reported bug that needs a plan before `/bug` executes it — the repro is unclear, the code area is unfamiliar, or the fix needs to be reviewed before it's made. Still minimal: no scout fan-out, no research phase.

## Process

1. **Pull the full report:** `gh issue view <NUMBER> --repo nicholasmartin/claude-workflow-template --comments` — the body and discussion are the repro source.
2. **Gather the evidence.** Read the logs/stack traces referenced in the issue and the implicated code paths directly. At most ONE `Explore` subagent is allowed, only if the codebase area is genuinely unfamiliar — and state why you're spending it. Its prompt must be self-contained and end with the read-only scout contract: report only, no file creation.
3. **Write the plan** to `.agents/plans/bug-<issue-number>-<kebab-slug>.md` with these sections:
   - **Repro** — exact steps/inputs, observed vs expected behavior
   - **Root cause hypothesis** — file:line plus the reasoning that points there
   - **Fix plan** — ordered tasks, where **task 1 is ALWAYS "write the failing test"** (or "record the red manual repro" if the project has no test framework)
   - **Observable truths** — 2–3 measurable outcomes that prove the bug is dead
   - **Validation commands** — exact, non-interactive
4. Keep the plan **≤80 lines**.

## Hand off

Recommend the executor at the end of the plan:

- `/bug <NUMBER>` — the normal path; its red-repro gate matches task 1
- `/execute <plan>` — if the fix spans multiple files/components and needs the full task-by-task treatment
