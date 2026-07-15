---
description: Minimal hotfix plan — what's broken, what's the fix, ship it
argument-hint: [issue-number-or-description]
---

# Plan Hotfix: Broken → Fix → Ship

## Target

$ARGUMENTS

## When to use

An urgent breakage where you want the root cause pinned down before `/hotfix` ships the fix. This is the deliberate opposite of `/plan-feature`'s 500-line template: no scout fan-out, no subagents, no research phase — read the evidence, name the cause, write a tiny plan.

## Process

1. **Read the report.** If the argument is an issue number, read it: `gh issue view <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}}`. Otherwise work from the description given.
2. **Inspect only the directly implicated files.** Follow the error/symptom to its source. No codebase survey — that's `/plan-feature` weight.
3. **Write the plan** to `.agents/plans/hotfix-<kebab-slug>.md`, containing exactly five sections:
   - **What's broken** — the symptom, with evidence (error text, log lines, failing command)
   - **Root cause** — file:line and the mechanism
   - **The fix** — the specific change to make
   - **Risk** — what could regress, and how you'd notice
   - **Validation** — 1–3 exact commands that prove the fix

Target **≤40 lines** of plan. If it won't fit in 40 lines, it isn't a hotfix — say so.

## Hand off

Tell the user the plan is ready and hand it to `/hotfix` — or to `/execute` if the diagnosis grew beyond hotfix weight (multiple components, architectural implications); say so explicitly if it did.
