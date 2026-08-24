---
description: Execute an implementation plan
argument-hint: [path-to-plan]
---

# Execute: Implement from Plan

## Plan to Execute

Read plan file: `$ARGUMENTS`

## Execution Instructions

### 0. Link to GitHub Issue(s) and the Sub-issue Map

- Ask the user which GitHub issue this plan implements (if not obvious from the plan)
- Read the issue body: `gh issue view <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}}`
- Move the board item to "In Progress": `./.claude/scripts/move-issue.sh <NUMBER> "In Progress"`
- Claim the issue for this session: `./.claude/scripts/claim-issue.sh <NUMBER> claim` (auto-detects the worktree; `main` in the main checkout). On `CLAIM COLLISION` (exit 3), stop and ask the user. The claim is **parent-only** — sub-issues ride the parent's worktree and are never claimed separately.
- **Load the sub-issue map** from the plan's `## TASK SUB-ISSUES` table. Each row maps a sub-issue to the plan tasks that implement it; the sub-issue carries the authoritative AC for that slice. Rules:
  - Do **NOT** bulk-move sub-issues now. Each one moves through its own lifecycle as its tasks are actually picked up (step 3).
  - `type:ops` rows are operator work: never execute them, never move them — list them in the output report as outstanding operator steps.
  - If the feature has sub-issues but the plan lacks the table (pre-mapping plans), fetch them once and map by title before starting:
    ```bash
    gh api graphql -f query='query { repository(owner: "{{REPO_OWNER}}", name: "{{REPO_NAME}}") { issue(number: <NUMBER>) { subIssues(first: 50) { nodes { number title labels(first:10){nodes{name}} } } } } }'
    ```

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
- **Sub-issue pickup:** if this is the FIRST task mapped to a sub-issue that is still Ready, move it now: `./.claude/scripts/move-issue.sh <SUB> "In Progress"`. Two sub-issues may legitimately be In Progress at once — execution doesn't always respect slice boundaries (a compiler-driven migration can touch several slices in one sweep); the map is task-granular, not sequential.

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

#### d. Close out the sub-issue slice

When the LAST task mapped to a sub-issue has passed its VALIDATE command **and** every verifier covering its tasks has reported PASS:

1. Check off the sub-issue's acceptance criteria (`gh issue edit <SUB> --repo {{REPO_OWNER}}/{{REPO_NAME}} --body "<updated body>"`)
2. Comment which plan tasks completed it
3. Move it to "In Review": `./.claude/scripts/move-issue.sh <SUB> "In Review"` — In Review means *work complete, not yet landed on the default branch*. Never close it or move it to Done here — closing happens at ship time (workflow.md §5).

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

Update the related GitHub issue(s):

- **Sub-issues first:** confirm every implementation sub-issue reached In Review with its AC checked (step 3d) — sweep any that slipped through. List `type:ops` sub-issues as outstanding operator work.
- **Feature issue:** check off its thin Definition of Done boxes now satisfied (`gh issue edit <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}} --body "<updated body>"`); on a small feature without sub-issues, check off its full AC instead.
- Comment with a summary: `gh issue comment <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}} --body "Implementation complete via /execute. Files changed: ... Commit pending."`
- **Never close anything or move anything to Done here** (CLAUDE.md rule): the feature issue stays In Progress, completed sub-issues sit at In Review, and closing happens at ship time — `/commit` on the default branch, or `/merge` / `/pr` + `/continue` for branch work.

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
