---
description: Push the current branch and open a pull request against the default branch
argument-hint: [--reviewer <handles>] [--draft]
---

# PR: Open a Pull Request for the Current Branch

Push the current branch and open a pull request against the default branch —
the **remote ending** of the ship layer (see workflow.md §5). Use it when the
repo requires review, or when someone else merges.
**This command never merges** — merging is the reviewer's call, done in GitHub. The issue closes
when the PR merges (via `Closes #N`); the board moves to **In Review** now and
is reconciled to Done by `/continue` after the merge.

The local ending — landing directly on the default branch yourself — is
`/merge`. Pick per branch, at ship time.

## Arguments

- `--reviewer <handles>` — request reviews (comma-separated GitHub handles or
  `org/team` slugs), passed through to `gh pr create`
- `--draft` — open the PR as a draft

## Step 1: Preconditions

Detect the default branch, then check the current state:

```bash
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||') \
  || DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
CUR=$(git branch --show-current)
git status --porcelain
git fetch origin
git rev-list --count "origin/$DEFAULT_BRANCH..HEAD"
```

(If `symbolic-ref` reports "not a symbolic ref", repair it once with
`git remote set-head origin --auto` after the fetch.)

Check, in order:

1. **Not on the default branch.** If `CUR` equals `$DEFAULT_BRANCH`, STOP —
   there's no branch to open a PR from. Run `/commit` first if there is
   uncommitted work, or start from a feature branch.
2. **Working tree clean.** If `git status --porcelain` is non-empty, STOP and
   suggest `/commit` to commit the outstanding changes before opening the PR.
3. **Commits ahead.** If the `rev-list` count is `0`, STOP — there's nothing to
   open a PR for.

## Step 2: Check for divergence from the default branch

```bash
git rev-list --count "HEAD..origin/$DEFAULT_BRANCH"
```

If greater than `0`, the branch is behind. **Warn the user** and offer to
rebase:

```bash
git rebase "origin/$DEFAULT_BRANCH"
```

Never force this — only rebase if the user agrees. If they decline, continue
with the PR as-is and note in the summary that the branch is behind.

## Step 3: Identify the issue and compose the PR

**Issue number (best-effort):** derive the plan slug from the branch name and
check `.agents/plans/<slug>.md` for the issue it implements; if not obvious,
ask the user (mirroring `/execute` Step 0). If there is genuinely no issue,
omit the `Closes` line entirely — never guess an issue number.

**Title:** `<type>(<scope>): <subject>` matching the branch's conventional-commit
type, or a short descriptive sentence if the branch mixes types. Base it on:

```bash
git log "origin/$DEFAULT_BRANCH..HEAD" --oneline
```

**Body** — fill from the branch's commits and this session's context:

```
## Summary
- <what changed and why>

## Testing
- <commands run / verify steps>

Closes #<issue>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

For `## Testing`, state what was actually run this session (validation
battery, tests, manual verification). If nothing was run, write exactly:
`Not run (PR content only).`

## Step 4: Create the PR

```bash
git push -u origin "$CUR"
gh pr create --base "$DEFAULT_BRANCH" --head "$CUR" --title "<title>" --body "<PR-BODY>"
```

- Invoked with `--draft` → add `--draft`.
- Invoked with `--reviewer <handles>` → add `--reviewer <handles>`.
- **If a PR already exists** for this branch, `gh pr create` exits 1 with
  `already exists` and the PR URL on stderr — that is not a failure: report the
  existing PR's URL, skip to Step 6 (the push above already updated it).

**Never invoke the merge subcommand of `gh pr`** — this command only opens the
PR. Merging is the reviewer's decision, made in GitHub.

## Step 5: Offer to open in browser

Ask the user if they'd like to view the PR:

```bash
gh pr view --web
```

## Step 6: Board → In Review

```bash
./.claude/scripts/move-issue.sh <issue-number> "In Review"
gh issue comment <issue-number> --repo {{REPO_OWNER}}/{{REPO_NAME}} --body "PR opened: <pr-url>"
```

Skip silently if no issue was identified in Step 3.

## What happens to the branch, worktree, and claim

**Nothing — deliberately.** The branch must exist on the remote for the PR;
the local worktree stays alive so review feedback can be addressed in place
(`git checkout <branch>`, fix, `/commit`, `git push`); the `worktree:*` claim
label stays held so other sessions don't pick the issue up. All three are
reconciled by `/continue` after the PR merges: board → Done, claim released,
branch/worktree cleanup offered (see workflow.md §10).

To keep building on this work before the PR merges, stack the next branch on
top of it inside the same worktree: `git checkout -b <next-branch>` — see
workflow.md §5.

## What this command does NOT do

- It does **not** merge the PR — this command never merges (no `gh pr` merge subcommand).
- It does not force-push or rewrite history — a rebase only happens with the
  user's explicit go-ahead (Step 2).
- It does not close issues, move the board to Done, or release claims — that
  happens when the work reaches the default branch (PR merge + `/continue`
  reconcile).
- It does not delete branches or worktrees.
