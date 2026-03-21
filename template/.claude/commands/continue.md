# Continue Development

You are resuming work on this project. Follow this procedure exactly.

## Step 1: Gather current state

Run these commands to understand where things stand:

1. Fetch open issues with labels and priority context:

```
gh issue list --repo {{REPO_OWNER}}/{{REPO_NAME}} --state open --json number,title,labels,state --limit 50
```

2. Fetch project board items with custom field values (Phase, Priority, Status):

```
gh project item-list {{PROJECT_NUMBER}} --owner @me --format json
```

3. Check git state (branch, uncommitted work, recent history):

```
git status
git log --oneline -10
git branch --show-current
```

## Step 2: Analyze and report

Based on the gathered data, produce a concise status report as a table:

| # | Issue | Phase | Priority | Status | Labels |
|---|-------|-------|----------|--------|--------|

Group by status: **In Progress** first, then **Ready**, then **Backlog**.

Then summarize:
- What is currently **In Progress** (if anything)
- What is **Ready** to pick up next
- Any **blockers** or decisions needed
- Uncommitted local changes (if any)

End with: "What would you like to work on?"

## Step 3: Determining work order

When the user picks a task, or if they ask you to suggest one, prioritize by:

1. Issues already marked "In Progress" on the project board
2. `priority:critical` and `priority:high` issues first
3. Within the same priority, lower issue numbers first (earlier work before later)
4. Look for dependency references in issue bodies ("depends on #X", "blocked by #Y")
5. The project board is the source of truth

## Key references

- **Repo:** `{{REPO_OWNER}}/{{REPO_NAME}}`
- **Project board:** Project #{{PROJECT_NUMBER}} under `@me` (ID: `{{PROJECT_ID}}`)
- **CLAUDE.md:** Project conventions and patterns
