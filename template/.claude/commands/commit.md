Create a new commit for all of our uncommitted changes during our current session. Only commit what we have worked on as there could be other files others have worked on.
run git status && git diff HEAD && git status --porcelain to see what files are uncommitted
add the untracked and changed files

## Pre-Commit: Placeholder Scan

Before committing, scan staged files for placeholders that should not ship:

```bash
# Scan staged .ts/.tsx/.js/.jsx files for placeholder markers
git diff --cached --name-only -- '*.ts' '*.tsx' '*.js' '*.jsx' | xargs grep -n -E '(TODO|FIXME|HACK|XXX)\b' 2>/dev/null || true
```

Also check for empty function bodies in staged files:

```bash
git diff --cached --name-only -- '*.ts' '*.tsx' '*.js' '*.jsx' | xargs grep -n -E '(function|=>)\s*\{\s*\}' 2>/dev/null || true
```

If any matches are found:

- List them with file and line number
- **Warn the user** but do NOT block the commit
- Ask: "Found [N] placeholder(s). Proceed with commit anyway?"
- If the user says yes, continue. If no, stop so they can fix.

If no matches are found, proceed silently.

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

After committing, check if the work completed relates to any open GitHub issues:

1. Run `gh issue list --repo {{REPO_OWNER}}/{{REPO_NAME}} --state open --json number,title,labels --limit 50` to see open issues
2. If the committed work relates to an open issue:
   - Comment on the issue with the commit hash: `gh issue comment <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}} --body "Progress: <commit-hash> - <brief description of what was done>"`
   - If the issue has acceptance criteria checkboxes and any are now satisfied, update the issue body to check them off
   - If ALL acceptance criteria are complete, close the issue: `gh issue close <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}} --comment "All acceptance criteria met in <commit-hash>."`
   - **Task sub-issues:** When closing a feature issue, check if it has task sub-issues:
     ```bash
     gh api graphql -f query='query { repository(owner: "{{REPO_OWNER}}", name: "{{REPO_NAME}}") { issue(number: <NUMBER>) { subIssues(first: 50) { nodes { number title state } } } } }'
     ```
     Close any open task sub-issues that have all their AC checked off, commenting with the commit hash on each.
3. If no open issues are affected, skip this step
