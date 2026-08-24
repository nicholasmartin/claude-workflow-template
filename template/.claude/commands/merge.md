---
description: Land the current feature branch on the default branch locally
argument-hint: []
disable-model-invocation: true
---

# Merge: Land the Current Branch Locally

Merge the current feature branch into the default branch, close out the issue,
and push — the **local ending** of the ship layer (see workflow.md §5). Use it
when you answer to no one on this repo and the next task needs this work under
it. The remote ending — open a PR and let someone else merge — is `/pr`. Pick
per branch, at ship time.

This command is the legitimate closing moment for issues: it is what puts the
work on the default branch (the invariant: *an issue closes only when its work
reaches the default branch*).

## Step 1: Preconditions

Detect the default branch and check the current state:

```bash
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||') \
  || DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
CUR=$(git branch --show-current)
git status --porcelain
git rev-list --count "$DEFAULT_BRANCH..HEAD" 2>/dev/null || echo "no-local-default-branch"
```

Check, in order:

1. **Not on the default branch.** If `CUR` equals `$DEFAULT_BRANCH`, STOP —
   there's nothing to land; work on the default branch ships via `/commit`
   directly.
2. **Working tree clean.** If `git status --porcelain` is non-empty, STOP and
   point at `/commit` — commit the work before landing it.
3. **Commits ahead.** If the `rev-list` count is `0`, STOP — the branch has
   nothing the default branch doesn't.

## Step 2: Branch-protection guard

**This check runs BEFORE anything is merged, closed, or pushed.**

```bash
PROTECTED=$(gh api "repos/{{REPO_OWNER}}/{{REPO_NAME}}/branches/$DEFAULT_BRANCH" --jq .protected) || PROTECTED=true
```

If `PROTECTED` is `true`, STOP with:

> The default branch (`$DEFAULT_BRANCH`) is protected — this repo lands work
> via pull requests. Run `/pr` instead.

Fail-safe: if the API call fails (offline, auth), assume protected and STOP
the same way — landing locally on a repo you can't verify is the risky path.
(This uses the branch object's `protected` boolean, which needs only read
access and reflects rulesets as well — NOT the admin-gated `/protection`
endpoint.)

## Step 3: Exit the worktree (if inside one)

If this session is inside a worktree (`git worktree list` shows the current
checkout under `.claude/worktrees/`), call `ExitWorktree` with
`action: "keep"`. **Never `remove` before merging — remove deletes the branch
and the work on it.** If already in the main checkout, skip this step.

## Step 4: Safety checks in the main checkout

- `git status --porcelain` — the main tree must be clean.
- No other session is mid-merge: two parallel sessions must **serialize their
  merges** — if another `/merge` or `/execute-isolated` session may be landing
  right now, ask the user before proceeding.

## Step 5: Land

```bash
git merge --no-ff <branch>
```

On conflict, STOP and hand the resolution to the user — never auto-resolve a
merge conflict. (`git merge --abort` restores the pre-merge state if they want
out.)

## Step 6: Close out the issue(s)

For the issue(s) this branch implements (from the plan file's issue reference,
or ask the user — mirror `/execute` Step 0):

1. Comment the landing: `gh issue comment <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}} --body "Landed on $DEFAULT_BRANCH in <merge-commit-hash>."`
2. Check off acceptance criteria now satisfied (edit the issue body).
3. **Sub-issue sweep first:** fetch the issue's task sub-issues (the
   `subIssues` GraphQL query from `/commit`); close every open sub-issue whose
   AC are all checked off, commenting the landing on each, and move each
   closed one to Done via `move-issue.sh`. `type:ops` sub-issues close only
   when their operator checklist is actually done.
4. **Close the parent only when ALL its sub-issues are closed AND its own
   Definition of Done is ticked** (small features without sub-issues: when all
   AC are met):
   `gh issue close <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}} --comment "All acceptance criteria met — landed in <merge-commit-hash>."`
5. **After every close, set the board Status yourself:**
   `./.claude/scripts/move-issue.sh <NUMBER> Done` — closing an issue does NOT
   move its board item.
6. **After every close, release the ownership claim:**
   `./.claude/scripts/claim-issue.sh <NUMBER> release` (no-op if unclaimed;
   sub-issues are never claimed).

If AC or sub-issues remain open (usually `type:ops` operator work), leave the
parent open (comment progress only) and tell the user what's outstanding —
that is the correct state, not a failure.

## Step 7: Push

```bash
git push origin "$DEFAULT_BRANCH"
```

If the push is rejected (non-fast-forward, policy), report it and leave the
local state intact — do not force-push. A policy rejection here usually means
the repo wanted `/pr`; the local merge can be unwound with
`git reset --hard origin/$DEFAULT_BRANCH` (the branch still has the work).

## Step 8: Cleanup — explicit, default KEEP

Ask the user:

> Delete the worktree and branch now? Default is **keep** — `/continue` offers
> garbage collection of fully-merged branches later.

Only on an explicit yes:

```bash
git worktree remove .claude/worktrees/<name>   # worktree FIRST —
git branch -d <branch>                         # a branch checked out in a worktree cannot be deleted
```

If `git worktree remove` refuses (dirty worktree, exit 128), surface it and
ask before retrying with `--force`. Deletion is never a side effect of
landing.

## What this command does NOT do

- It does not run on the default branch (nothing to land).
- It does not merge when the default branch is protected — it redirects to `/pr`.
- It does not auto-resolve conflicts, force-push, or rewrite history.
- It does not delete branches or worktrees without an explicit yes.
