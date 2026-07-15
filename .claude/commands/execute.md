---
description: Execute an implementation plan
argument-hint: [path-to-plan]
---

# Execute: Implement from Plan

## Plan to Execute

Read plan file: `$ARGUMENTS`

## Execution Instructions

### 0. Link to GitHub Issue

- Ask the user which GitHub issue this plan implements (if not obvious from the plan)
- Read the issue body: `gh issue view <NUMBER> --repo nicholasmartin/claude-workflow-template`
- Move the board item to "In Progress": `./.claude/scripts/move-issue.sh <NUMBER> "In Progress"`
- Claim the issue for this session: `./.claude/scripts/claim-issue.sh <NUMBER> claim` (auto-detects the worktree; `main` in the main checkout). On `CLAIM COLLISION` (exit 3), stop and ask the user.

### 1. Pre-flight Checks

Before doing anything else, run these checks and report results:

```bash
# 1. Git status must be clean (no uncommitted changes)
git status --porcelain

# 2. Dependencies installed
npm ls --depth=0 2>&1 | head -5

# 3. Environment configured
test -f .env.local && echo "OK: .env.local exists" || test -f .env && echo "OK: .env exists" || echo "MISSING: environment file"

# 4. Current branch
git branch --show-current
```

Report results as a checklist:

- [ ] Git working tree clean
- [ ] Dependencies installed
- [ ] Environment file present
- [ ] On expected branch

**If git is dirty:** stop and ask whether to stash, commit, or abort.
**If dependencies are missing:** run `npm install` and continue.
**If env file is missing:** stop and ask the user to configure it.

### 2. Read and Understand

- Read the ENTIRE plan carefully
- Understand all tasks and their dependencies
- Note the validation commands to run
- Review the testing strategy

### 3. Execute Tasks in Order

For EACH task in "Step by Step Tasks":

#### a. Navigate to the task

- Identify the file and action required
- Read existing related files if modifying

#### b. Implement the task

- Follow the detailed specifications exactly
- Maintain consistency with existing code patterns
- Include proper type hints and documentation
- Add structured logging where appropriate

> Per-edit lint feedback arrives automatically via the PostToolUse hook (see workflow.md § Hook Layer) — fix anything it reports before moving on.

#### c. Spawn the task verifier

After the task's VALIDATE command passes, spawn one verification subagent (`subagent_type: Explore`). The verifier sees none of this conversation — its prompt must contain, verbatim:

- The full task block from the plan (ACTION / IMPLEMENT / VERIFY / DONE lines)
- The exact file paths the task touched
- Any Observable Truths from the plan this task contributes to

Instruct it: _"Independently confirm the VERIFY and DONE claims with fresh eyes — read the artifacts; run the task's VALIDATE command only if it is read-only/idempotent. Do not trust the builder's claims. Your final message: `VERDICT: PASS` or `VERDICT: FAIL — <evidence with file:line>`, nothing else on PASS."_

Verifiers report, never repair — if a verifier finds a problem, you fix it and re-verify. You may proceed to the next task while verifiers run in the background; the hooks check deterministic conditions, the verifier checks the task's *claims* — don't ask it to re-run lint.

### 4. Implement Testing Strategy

After completing implementation tasks:

- Create all test files specified in the plan
- Implement all test cases mentioned
- Follow the testing approach outlined
- Ensure tests cover edge cases

### 5. Final Validation

**Verdict gate:** do not begin Final Validation until every task verifier has reported and every `VERDICT: FAIL` is fixed and re-verified. If a verifier never reports (crashed subagent), re-spawn that one verifier.

The end-of-turn validation battery runs automatically via the Stop hook (see workflow.md § Hook Layer) — your turn cannot end while it fails; fix anything it reports.

Additionally, execute the plan's project-specific validation commands (the hook doesn't know the plan) in order, and fix failures until every command passes.

### 6. Final Verification

Spawn one final verification subagent (`subagent_type: Explore`) with the plan's complete OBSERVABLE TRUTHS section in its prompt. It independently confirms each truth against the working tree and reports per-truth PASS/FAIL with evidence. Unresolved FAILs block the "Ready for Commit" claim — fix and re-verify.

Then confirm before completing:

- All tasks from plan completed
- All tests created and passing
- All validation commands pass
- Per-task verdicts all PASS; final Observable-Truths verifier all PASS
- Code follows project conventions
- Documentation added/updated as needed

## Output Report

Provide summary:

### Completed Tasks

- List of all tasks completed
- Files created (with paths)
- Files modified (with paths)

### Tests Added

- Test files created
- Test cases implemented
- Test results

### Validation Results

```bash
# Output from each validation command
```

### Verification

- Per-task verifier verdicts (task → PASS, or FAIL → what was fixed → re-verified PASS)
- Final Observable-Truths verifier result (per-truth)

### GitHub Issue Update

Update the related GitHub issue:

- Check off completed acceptance criteria in the issue body using `gh issue edit <NUMBER> --repo nicholasmartin/claude-workflow-template --body "<updated body>"`
- Comment with a summary: `gh issue comment <NUMBER> --repo nicholasmartin/claude-workflow-template --body "Implementation complete via /execute. Files changed: ... Commit pending."`
- If ALL acceptance criteria are met, note that the issue is ready to close (close it after the commit)
- Move the board item to "Done" if fully complete (or leave "In Progress" if partially done)

### Ready for Commit

- Confirm all changes are complete
- Confirm all validations pass
- Confirm GitHub issue is updated
- Ready for `/commit` command

## Deviation Rules

When executing a plan, deviations from the spec will happen. Use these four rules to decide how to handle them:

### 1. Fix bugs inline (OK to deviate)

If you discover a bug in existing code while implementing a task, fix it in the same change. No need to stop or ask.
**Example:** You're adding a new server action and notice an existing action has a missing null check that would cause a crash. Fix it and note it in the output report.

### 2. Add validation at boundaries (OK to deviate)

If the plan omits input validation, type guards, or error handling at system boundaries (user input, API responses, database results), add them.
**Example:** The plan says "insert row into table" but doesn't validate that required fields are present. Add the validation before the insert.

### 3. Fix blockers pragmatically (OK to deviate, but document)

If a task can't be completed as specified because of an unexpected dependency, missing API, or incorrect assumption in the plan, find the simplest working alternative. Document what changed and why in the output report.
**Example:** The plan says to use an RPC that doesn't exist yet. Instead of stopping, create the RPC as part of the migration, note the addition, and continue.

### 4. STOP for architecture changes (NOT OK to deviate)

If completing a task would require changing the project's architecture, adding new dependencies not mentioned in the plan, restructuring the database schema beyond what's specified, or altering auth/middleware behavior, STOP and ask before proceeding.
**Example:** The plan says "add a column to users" but you realize the feature actually needs a new junction table. Stop and ask.

## Notes

- Don't skip validation steps
- If tests fail, fix implementation until they pass
