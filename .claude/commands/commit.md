Create a new commit for all of our uncommitted changes during our current session. Only commit what we have worked on as there could be other files others have worked on.
run git status && git diff HEAD && git status --porcelain to see what files are uncommitted
add the untracked and changed files

## Pre-Commit: Placeholder Scan

After staging, run the deterministic scan (detects TODO/FIXME markers, empty function bodies, empty catch blocks, and `.only`/`.skip` in test files — see workflow.md § Hook Layer):

```bash
./.claude/hooks/pre-commit-scan.sh
```

If it prints findings:

- Relay them to the user with file and line numbers
- **Warn the user** but do NOT block the commit
- Ask: "Found [N] placeholder(s). Proceed with commit anyway?"
- If the user says yes, continue. If no, stop so they can fix.

If it prints nothing, proceed silently.

## Commit

Add an atomic commit message with an appropriate message

add a tag such as "feat", "fix", "docs", etc. that reflects our work

### AI Context Tracking

After staging files, check if any AI context assets were modified:

```bash
git diff --cached --name-only | grep -E '^(CLAUDE\.md|\.claude/rules/|\.claude/commands/|\.claude/docs/|\.claude/skills/|\.claude/workflow\.md)' || true
```

If any AI context files are in the staged diff, append a `Context:` section to the commit body. This section describes what changed in the AI layer and why, so future sessions using `git log` can trace the evolution of rules, commands, and conventions.

Format:

```
<type>(<scope>): <subject>

<body describing code changes>

Context:
- Updated .claude/rules/server-actions.md with archive action pattern
- Added deviation rule to .claude/commands/execute.md
- Expanded CLAUDE.md Issue Tracking section with project board field rules

Closes #123
```

Rules for the Context section:

- Describe **what changed and why**, not just file paths
- One bullet per file or logical change
- Keep descriptions concise (one line each)
- If only AI context files changed (no code), the commit tag should be `docs` or `chore`
- If no AI context files are in the diff, omit the Context section entirely

## Post-Commit: Update GitHub Issues

After committing, check if the work completed relates to any open GitHub issues.

**First, the closing gate — issues close only when the work reaches the default
branch:**

```bash
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||') \
  || DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
CUR=$(git branch --show-current)
```

- **On the default branch** (`CUR` == `$DEFAULT_BRANCH`): full flow below,
  including closing.
- **On any other branch** (or detached HEAD — empty `CUR` counts as
  non-default): comment progress and check off acceptance criteria as below,
  but do **NOT** close issues, move board items to Done, or release claims.
  End the report with: "On branch `<CUR>` — issue #<N> stays open until this
  lands on `<default>`. Ship it with `/merge` or `/pr`."
- **Escape hatch:** if invoked as `/commit --close`, skip the gate and close
  anyway (explicit user override for work that will never flow through a ship
  step).

Then:

1. Run `gh issue list --repo nicholasmartin/claude-workflow-template --state open --json number,title,labels --limit 50` to see open issues
2. If the committed work relates to an open issue:
   - Comment on the issue with the commit hash: `gh issue comment <NUMBER> --repo nicholasmartin/claude-workflow-template --body "Progress: <commit-hash> - <brief description of what was done>"`
   - If the issue has acceptance criteria checkboxes and any are now satisfied, update the issue body to check them off
   - **Task sub-issues (every commit, gate or no gate):** if the committed work completes plan tasks mapped to sub-issues (the plan's `## TASK SUB-ISSUES` table), comment the commit hash on each affected sub-issue and check off any of its AC now satisfied. This is what makes the close-time sweep below actually fire at ship time — sub-issue ACs that nothing ticks can never close.
   - **The steps below run only when the closing gate is open (default branch, or `--close`):**
   - **Sub-issues close FIRST, then the parent.** Fetch the feature issue's sub-issues:
     ```bash
     gh api graphql -f query='query { repository(owner: "nicholasmartin", name: "claude-workflow-template") { issue(number: <NUMBER>) { subIssues(first: 50) { nodes { number title state labels(first:10){nodes{name}} } } } } }'
     ```
     Close any open sub-issue whose AC are all checked off, commenting with the commit hash. `type:ops` sub-issues close only when their operator checklist is genuinely done — never assume it from code landing.
   - **A feature issue closes only when ALL its sub-issues are closed (`type:ops` included) AND its own Definition of Done boxes are ticked** (for small features without sub-issues: when all its AC are complete). Then: `gh issue close <NUMBER> --repo nicholasmartin/claude-workflow-template --comment "All acceptance criteria met in <commit-hash>."` If sub-issues remain open (usually operator work), comment what remains and leave the parent open — that is correct, not a failure.
   - **After every close, set the board Status yourself:** `./.claude/scripts/move-issue.sh <NUMBER> Done` — closing an issue does NOT move its board item. The "item closed → Done" automation is optional UI configuration that may not be enabled; never rely on it. This applies to feature issues and task sub-issues alike.
   - **After every close, release the ownership claim:** `./.claude/scripts/claim-issue.sh <NUMBER> release` — removes any `worktree:*` label (no-op if unclaimed; sub-issues are never claimed, so this is parent-only in practice).
3. If no open issues are affected, skip this step
