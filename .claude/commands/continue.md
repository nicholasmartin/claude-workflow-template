# Continue Development

You are resuming work on this project. Follow this procedure exactly.

## Step 1: Current state (auto-gathered)

Board and issue state:
!`./.claude/scripts/board-state.sh`

Git state:
!`git status --porcelain; git log --oneline -10; git branch --show-current`

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

- **Repo:** `nicholasmartin/claude-workflow-template`
- **Project board:** Project #18 under `@me` (ID: `PVT_kwHOAC3aXM4BdVs6`)
- **CLAUDE.md:** Project conventions and patterns
