---
description: Execute an implementation plan inside an isolated git worktree
argument-hint: [path-to-plan]
disable-model-invocation: true
---

# Execute Isolated: Run a Plan in a Git Worktree

This command works in a **git worktree** using the `EnterWorktree` tool. It is the
isolation envelope around the existing executors: the same flow as `/execute` (or
`/execute-team`), but in a fresh checkout under `.claude/worktrees/<name>/` — the
main working tree is never touched until the final merge.

## When to use this vs /execute

- **/execute** (or **/execute-team**) — one plan, nothing else in flight. The
  merge-back ceremony buys nothing; skip it.
- **/execute-isolated** — use when any of these hold:
  - running two or more plans in parallel (one terminal + one worktree each),
  - you want cheap rollback — a failed run is discarded without dirtying the main tree,
  - the change is risky or sprawling and the main tree must stay usable meanwhile.

## Arguments

- **Plan path**: `$ARGUMENTS` — markdown plan file (ideally produced by `/plan-feature`)

## Step 1: Worktree gate

**Check this before anything else.** If the `EnterWorktree` tool is not available
in this session, STOP with:

> Worktree tools are not available in this session (Claude Code ≥ 2.1.208
> recommended). Run `/execute <plan>` instead — the single-agent executor handles
> the same plan in the main working tree.

## Step 2: Read the plan FIRST — before entering the worktree

Read the plan file at `$ARGUMENTS` in full, now.

Worktrees branch from `origin/<default-branch>` by default (`worktree.baseRef:
"fresh"`) — an uncommitted or unpushed plan file will NOT exist inside the
worktree. After entering (Step 4), if the plan file is missing there, re-create it
verbatim from what you read in this step before executing anything.

## Step 3: Link to GitHub Issue → In Progress

- Ask the user which GitHub issue this plan implements (if not obvious from the plan)
- Read the issue body: `gh issue view <NUMBER> --repo nicholasmartin/claude-workflow-template`
- Move the board item to "In Progress": `./.claude/scripts/move-issue.sh <NUMBER> "In Progress"`

**Never close issues or move them to Done here — only `/commit` closes issues.**

## Step 4: Enter the worktree

Call `EnterWorktree` with `name` set to the plan filename's slug (plan
`level-5-coordination.md` → name `level-5-coordination`). Re-using a name
**resumes** that worktree (a clean, never-committed one resets to the current
base); to force a fresh tree instead of resuming a half-finished run, pick a
suffixed name (`<slug>-2`).

Then pre-flight inside the worktree:

```bash
git branch --show-current   # expect a worktree branch, not the default branch
git status --porcelain      # expect clean
# Keep worktree checkouts out of git status (self-healing; creates a 1-line diff to commit if it fires):
grep -qxF '.claude/worktrees/' .gitignore 2>/dev/null || echo '.claude/worktrees/' >> .gitignore
```

If the plan file is missing here, re-create it now (Step 2).

## Step 5: Execute the plan (executor choice)

Pick the executor the plan's NOTES recommend — default `/execute`:

- **Single-agent (default):** Read `.claude/commands/execute.md` and follow its
  Execution Instructions **steps 1–6 exactly** (skip its step 0 — done above). All
  of it applies unchanged: pre-flight, task loop, per-task verifiers, verdict gate,
  final validation, Observable-Truths verifier, deviation rules.
- **Team (when the plan recommends `/execute-team`):** Read
  `.claude/commands/execute-team.md` and follow it **from its Step 1** (skip its
  Step 0 — done above). Its feature-flag gate still applies, softened here: if
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is unset, fall back to the single-agent
  path above **in this same worktree** instead of stopping.

Either path: **worktree lifecycle (enter/exit/merge) belongs to this session only
— teammates and subagents never call `EnterWorktree`/`ExitWorktree`** (subagents
cannot call `ExitWorktree` at all). Do not duplicate either flow here.

## Step 6: Commit on the worktree branch

Run the `/commit` flow while still inside the worktree. The commit lands on the
worktree branch; `gh` issue updates work normally — the board is shared state, the
tree is not. `/commit` closes issues exactly as it always does.

## Step 7: Exit and merge back

1. Call `ExitWorktree` with `action: "keep"`. **Never `remove` before merging —
   remove deletes the branch and the work on it.**
2. Back in the main checkout, confirm it is safe to merge:
   - `git status --porcelain` — main tree clean
   - no other session is mid-merge (two parallel `/execute-isolated` sessions must
     serialize their merges — ask the user if unsure)
3. Merge and clean up:

```bash
git merge --no-ff <worktree-branch>
git worktree remove .claude/worktrees/<name>
git branch -d <worktree-branch>
```

## Rollback: abandoning a run

To abandon a run, call `ExitWorktree` with `action: "remove"`. If it refuses
because of uncommitted or unmerged work, confirm with the user before retrying
with `discard_changes: true`. The main tree is untouched either way.

## Notes

- Parallel usage: N terminals × N worktrees — each terminal runs its own
  `/execute-isolated <plan>`; the GitHub board is the shared state. Coordination
  conventions (worktree ownership labels) arrive in Level 5.
- `ExitWorktree` never merges anything — merge-back is always the explicit Step 7.
- Gitignored files (`.env`, `.claude/settings.local.json`) are absent in
  worktrees. If the project needs them, add a `.worktreeinclude` file (gitignore
  syntax) at the repo root — see the Claude Code worktrees docs.
- Ending the session while still inside a worktree: a clean worktree is
  auto-removed with its branch; a dirty one prompts keep-or-remove.
