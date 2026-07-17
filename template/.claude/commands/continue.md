# Continue Development

You are resuming work on this project. Follow this procedure exactly.

## Step 1: Current state (auto-gathered)

Board and issue state:
!`./.claude/scripts/board-state.sh`

Git state:
!`git status --porcelain; git log --oneline -10; git branch --show-current; git worktree list`

Merged-PR probe (local branches whose PR already merged upstream):
!`DEF=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'); for BR in $(git for-each-ref --format='%(refname:short)' refs/heads/); do [ "$BR" = "$DEF" ] && continue; M=$(gh pr list --head "$BR" --state merged --json number,mergedAt --jq '.[0].number' 2>/dev/null); [ -n "$M" ] && echo "MERGED: $BR (PR #$M)"; done; true`

## Step 2: Reconcile shipped work

For each `MERGED:` branch from the probe (skip this step if there are none),
the work is on the default branch upstream but local state lags. Reconcile:

1. **Pull:** `git checkout <default-branch> && git pull`
2. **Board + claim — always run both, even if `Closes #N` already closed the
   issue** (GitHub's auto-close never moves the board item or removes labels):
   - if the linked issue is still open, close it with a comment referencing the PR
   - `./.claude/scripts/move-issue.sh <NUMBER> Done`
   - `./.claude/scripts/claim-issue.sh <NUMBER> release`
3. **Stack check before any deletion:**
   `git branch --contains <BR> | grep -v " <BR>$"` — any *other* branch listed
   descends from `<BR>`. If so, do **NOT** delete `<BR>`; instead offer the
   stack-down rebase with the names filled in:
   `git rebase --onto origin/<default-branch> <BR> <descendant>` (then re-run
   this reconcile — `<BR>` becomes deletable once nothing descends from it).
4. **Offer cleanup (consent-gated, mirror the stale-claim rule):** never delete
   silently — ask first. On yes:
   - if a worktree has `<BR>` checked out (`git worktree list`), remove it
     first: `git worktree remove <path>` (a checked-out branch cannot be
     deleted)
   - `git branch -D <BR>` — `-D` is required: after a squash-merge the branch
     is never "fully merged" in git's eyes; the PR's MERGED state (the probe)
     is the source of truth.

## Step 3: Analyze and report

Based on the gathered data, produce a concise status report as a table:

| # | Issue | Phase | Priority | Status | Labels | Claim | PR |
|---|-------|-------|----------|--------|--------|-------|-----|

The **Claim** column is the `<name>` part of a `worktree:<name>` label, or `—`
if unclaimed. The **PR** column: `open` for a branch with an open PR (board
should read In Review), `merged` if the probe flagged it (reconcile pending —
Step 2), or `—`. Group by status: **In Progress** first, then **In Review**,
then **Ready**, then **Backlog**.

Then summarize:
- What is currently **In Progress** (if anything)
- Issues **claimed by another session** (`worktree:*` label), and whether each
  claim looks **stale** — its worktree missing from `git worktree list` and not
  `main`
- What is **Ready** to pick up next
- Any **blockers** or decisions needed
- Uncommitted local changes (if any)

End with: "What would you like to work on?"

## Step 4: Determining work order

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

- **Repo:** `{{REPO_OWNER}}/{{REPO_NAME}}`
- **Project board:** Project #{{PROJECT_NUMBER}} under `@me` (ID: `{{PROJECT_ID}}`)
- **CLAUDE.md:** Project conventions and patterns
