---
name: workflow
description: Modify or improve the project workflow system. Use when changing how slash commands, GitHub Issues/Projects, or work tracking processes operate. Ensures all related pieces (commands, project config, CLAUDE.md rules, workflow docs) get updated together.
---

# Workflow: Modify Project Management System

## When to Use

Use this skill when:
- Changing how a slash command interacts with GitHub (e.g., updating /commit to handle sub-issues differently)
- Adding, removing, or modifying GitHub Project fields, views, or automations
- Changing the issue hierarchy structure (epics, features, tasks)
- Updating the label taxonomy
- Adding a new slash command that interacts with GitHub
- Changing how plan files or PRDs relate to GitHub issues
- Rethinking any part of the workflow lifecycle

## Process

### Step 1: Understand Current State

Read all of these before making any changes:

1. **Workflow doc:** `.claude/workflow.md` (the source of truth for the entire system)
2. **All slash commands:**
   - `.claude/commands/commit.md`
   - `.claude/commands/continue.md`
   - `.claude/commands/execute.md`
   - `.claude/commands/execute-team.md`
   - `.claude/commands/execute-isolated.md`
   - `.claude/commands/merge.md`
   - `.claude/commands/pr.md`
   - `.claude/commands/hotfix.md`
   - `.claude/commands/chore.md`
   - `.claude/commands/bug.md`
   - `.claude/commands/plan-feature.md`
   - `.claude/commands/plan-hotfix.md`
   - `.claude/commands/plan-bug.md`
   - `.claude/commands/status.md`
   - `.claude/commands/create-prd.md`
   - `.claude/commands/create-rules.md`
   - `.claude/commands/prime.md`
   - `.claude/commands/init-project.md`
3. **Hook layer:** `.claude/settings.json` (wiring) and `.claude/hooks/*.sh` (post-edit-lint, stop-validate, pre-commit-scan, optional validate-local)
4. **Plumbing scripts:** `.claude/scripts/*.sh` (board-state, move-issue, create-issue, claim-issue, add-field-option — the canonical GitHub interaction path)
5. **CLAUDE.md** sections that reference GitHub or workflow (Decision Protocol, Scope Enforcement)
6. **GitHub Project state:**
   ```bash
   # Fields
   gh project field-list {{PROJECT_NUMBER}} --owner @me --format json
   # Views
   gh api graphql -f query='{ user(login: "{{REPO_OWNER}}") { projectV2(number: {{PROJECT_NUMBER}}) { views(first: 20) { nodes { name layout filter } } } } }'
   # Automations (check in UI, not available via API)
   ```
7. **Memory files** in the memory directory that reference workflow or issue lifecycle

### Step 2: Identify the Change

Clearly define:
- **What is changing** (the specific modification)
- **Why it's changing** (the problem being solved or improvement being made)
- **What it affects** (which components need updating)

### Step 3: Impact Analysis

Map the change against all components. Check each box for components that need updating:

- [ ] `.claude/workflow.md` (almost always needs updating)
- [ ] `.claude/commands/commit.md`
- [ ] `.claude/commands/continue.md`
- [ ] `.claude/commands/execute.md`
- [ ] `.claude/commands/execute-team.md`
- [ ] `.claude/commands/execute-isolated.md`
- [ ] `.claude/commands/merge.md`
- [ ] `.claude/commands/pr.md`
- [ ] `.claude/commands/hotfix.md`
- [ ] `.claude/commands/chore.md`
- [ ] `.claude/commands/bug.md`
- [ ] `.claude/commands/plan-feature.md`
- [ ] `.claude/commands/plan-hotfix.md`
- [ ] `.claude/commands/plan-bug.md`
- [ ] `.claude/commands/status.md`
- [ ] `.claude/commands/create-prd.md`
- [ ] `.claude/commands/create-rules.md`
- [ ] `.claude/commands/prime.md`
- [ ] `.claude/commands/init-project.md`
- [ ] `CLAUDE.md` (project rules)
- [ ] `.claude/settings.json` (hook wiring)
- [ ] `.claude/hooks/*.sh` (validation hook scripts)
- [ ] `.claude/scripts/*.sh` (board plumbing: board-state, move-issue, create-issue, claim-issue, add-field-option)
- [ ] GitHub Project fields (add/remove/rename via `gh project field-*`)
- [ ] GitHub Project views (must be done in UI)
- [ ] GitHub Project automations (must be done in UI)
- [ ] Label taxonomy (add/remove labels via `gh label *`)
- [ ] Memory files (workflow preferences, feedback)
- [ ] This skill file (`.claude/skills/workflow/SKILL.md`)

### Step 4: Present the Plan

Before making any changes, present the user with:

```
## Proposed Workflow Change

**Change:** [what]
**Reason:** [why]

### Components to Update

| Component | Change | Details |
|-----------|--------|---------|
| workflow.md | Update section X | [specifics] |
| /commit | Add sub-issue closing | [specifics] |
| ... | ... | ... |

### Components NOT Affected
- [list unaffected components so user can verify nothing was missed]

### Manual Steps Required (if any)
- [GitHub UI changes that can't be done via API]

Proceed?
```

Wait for user confirmation before implementing.

### Step 5: Implement Changes

Execute the plan in this order:

1. **GitHub Project changes first** (fields, labels) since commands reference these IDs
2. **Slash commands** (update all affected commands)
3. **CLAUDE.md** (update rules if affected)
4. **workflow.md** (update to reflect the new state)
5. **Memory files** (update or create if needed)

### Step 6: Verify

After implementing:

1. Re-read the updated workflow.md and verify it's internally consistent
2. Check that all slash commands reference correct field IDs, project IDs, and workflows
3. List any GitHub UI changes the user needs to make manually
4. Summarize what changed and what the user should test

## Key References

| Resource | Location | Purpose |
|----------|----------|---------|
| Workflow doc | `.claude/workflow.md` | Source of truth for the system |
| Slash commands | `.claude/commands/*.md` | Command definitions |
| Project rules | `CLAUDE.md` | Decision protocol, scope enforcement |
| Project board | GitHub Project #{{PROJECT_NUMBER}} | Issue tracking |
| Project ID | `{{PROJECT_ID}}` | For `gh project` commands |
| Repo | `{{REPO_OWNER}}/{{REPO_NAME}}` | For `gh issue` commands |

## Guardrails

- **Never update a command without updating workflow.md** to match
- **Never change a hook script or settings.json without updating workflow.md § Hook Layer** in the same change
- **Never change a scout or verifier prompt spec in a command without updating workflow.md § Subagent Layer** in the same change
- **Never add a GitHub field without documenting it** in workflow.md section 2
- **Never change label taxonomy without updating** workflow.md section 4
- **Never change the claim convention (claim-issue.sh, worktree: labels) without updating workflow.md section 10, Coordination Layer** in the same change
- **Test command syntax** by reading the updated command file and verifying `gh` commands reference valid field/option IDs
- **Note UI-only changes** clearly, since views and automations can't be configured via API
