# Continue Development

You are resuming work on this project. Follow this procedure exactly.

## Step 1: Current state (auto-gathered)

Board and issue state:
!`./.claude/scripts/board-state.sh`

Git state:
!`git status --porcelain; git log --oneline -10; git branch --show-current; git worktree list`

## Step 2: Analyze and report

Based on the gathered data, produce a concise status report as a table:

| # | Issue | Phase | Priority | Status | Labels | Claim |
|---|-------|-------|----------|--------|--------|-------|

The **Claim** column is the `<name>` part of a `worktree:<name>` label, or `—`
if unclaimed. Group by status: **In Progress** first, then **Ready**, then
**Backlog**.

Then summarize:
- What is currently **In Progress** (if anything)
- Issues **claimed by another session** (`worktree:*` label), and whether each
  claim looks **stale** — its worktree missing from `git worktree list` and not
  `main`
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
6. Skip issues claimed by another session — a `worktree:<name>` label counts as
   claimed unless `<name>` matches this session's worktree (or `main` when
   running in the main checkout)
7. Stale claims (claimed worktree absent from `git worktree list`, claim not
   `main`) are surfaced, never silently taken: ask the user before clearing one
   with `./.claude/scripts/claim-issue.sh <NUMBER> release`

## Key references

- **Repo:** `nicholasmartin/claude-workflow-template`
- **Project board:** Project #18 under `@me` (ID: `PVT_kwHOAC3aXM4BdVs6`)
- **CLAUDE.md:** Project conventions and patterns
