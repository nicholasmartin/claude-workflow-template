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

### 4. Implement Testing Strategy

After completing implementation tasks:

- Create all test files specified in the plan
- Implement all test cases mentioned
- Follow the testing approach outlined
- Ensure tests cover edge cases

### 5. Final Validation

The end-of-turn validation battery runs automatically via the Stop hook (see workflow.md § Hook Layer) — your turn cannot end while it fails; fix anything it reports.

Additionally, execute the plan's project-specific validation commands (the hook doesn't know the plan) in order, and fix failures until every command passes.

### 6. Final Verification

Before completing:

- All tasks from plan completed
- All tests created and passing
- All validation commands pass
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
