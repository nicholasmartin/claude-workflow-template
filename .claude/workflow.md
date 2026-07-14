# Claude Workflow Template Workflow: GitHub-Driven Project Management

**Version:** 1.0
**Status:** Active

This document defines how Claude Workflow Template manages work through GitHub Issues, Projects, and Claude Code slash commands. It is the single reference for the workflow system and should be updated whenever the process changes.

---

## 1. Core Principles

- **GitHub is the source of truth** for what needs to be done, what's in progress, and what's complete.
- **PRD files stay in the repo** (`.claude/*.md`) for holistic specs, architecture, and cross-cutting concerns. They are version-controlled and reviewable.
- **Plan files stay in the repo** (`.agents/plans/*.md`) as detailed implementation guides with code patterns, context references, and validation commands.
- **GitHub Issues track status.** Plan files describe how to build. PRDs describe what to build.
- **One project board, multiple views.** Views provide different perspectives (bugs, active work, backlog, epics) without duplicating data.

---

## 2. GitHub Project Structure

### Project Board

- **Project:** Claude Workflow Template Roadmap (#18)
- **Project ID:** `PVT_kwHOAC3aXM4BdVs6`
- **Repo:** `nicholasmartin/claude-workflow-template`

### Custom Fields

| Field             | Type          | Values                                  | Purpose                                                             |
| ----------------- | ------------- | --------------------------------------- | ------------------------------------------------------------------- |
| **Status**        | Single select | Backlog, Ready, In Progress, Done       | Workflow state                                                      |
| **Phase**         | Single select | Phase 1-N (add new phases as needed)    | Groups work by development phase                                    |
| **Priority**      | Single select | Low, Medium, High, Critical             | Importance ranking                                                  |

### Views

| View            | Layout                    | Filter                       | Purpose                                         |
| --------------- | ------------------------- | ---------------------------- | ----------------------------------------------- |
| **Epics**       | Table (hierarchy enabled) | `has:phase`                  | Phase-level overview with expandable sub-issues |
| **Bugs**        | Board                     | `label:type:bug`             | All bugs, grouped by status                     |
| **Active Work** | Board (by Status)         | `status:Ready,"In Progress"` | Daily working view, no backlog noise            |
| **Backlog**     | Board                     | `status:Backlog`             | Everything not yet started                      |

### Automations

| Automation   | Trigger                   | Action               |
| ------------ | ------------------------- | -------------------- |
| Auto-add     | New issue created in repo | Add to project board |
| Item closed  | Issue closed              | Set Status to Done   |
| Auto-archive | Item in Done for 14+ days | Archive item         |

---

## 3. Issue Hierarchy

Work is organized in a three-level hierarchy using GitHub's parent/sub-issue feature:

```
Phase Epic (parent issue)
  e.g., #1 "Phase 1: Foundation"
  - Summary of the phase goals
  - Links to PRD section
  - Progress bar auto-calculated from sub-issues
  |
  +-- Feature Issue (sub-issue)
  |     e.g., #5 "Add user authentication"
  |     - User story
  |     - Context/problem description
  |     - Acceptance criteria (checkboxes)
  |     - Link to plan file (.agents/plans/*.md)
  |     - Labels: phase, type, priority, area
  |     |
  |     +-- Task Sub-issue (optional, for larger features)
  |           e.g., "Configure JWT token refresh"
  |           - Specific implementation steps
  |           - Validation commands
  |
  +-- Feature Issue (sub-issue)
        ...
```

### When to create each level

- **Phase Epic:** Once per development phase. Created when a new phase begins.
- **Feature Issue:** One per distinct feature or piece of work. Created by `/plan-feature`.
- **Task Sub-issue:** Optional. Use for larger features where you want granular progress tracking.

### Phase-less issues

Not all issues belong to a phase. Bugs, polish items, and ad-hoc improvements may exist without a Phase field. These are tracked by Status and visible in the Backlog, Active Work, and Bugs views.

---

## 4. Labels

Labels categorize issues for filtering. Applied to individual issues, not epics.

### Label Taxonomy

| Category     | Labels                                                                                          | Purpose                       |
| ------------ | ----------------------------------------------------------------------------------------------- | ----------------------------- |
| **Phase**    | `phase:1` through `phase:N` (add more as needed)                                                | Which development phase       |
| **Type**     | `type:feature`, `type:bug`, `type:infra`, `type:polish`, `type:dx`, `type:tech-debt`, `type:docs` | What kind of work           |
| **Priority** | `priority:critical`, `priority:high`, `priority:medium`, `priority:low`                         | How urgent                    |
| **Area**     | (project-specific, add as needed)                                                                | What part of the system       |
| **Source**   | `source:research`, `source:user-report`, `source:internal`                                      | Where the issue came from     |

---

## 5. Workflow: From Idea to Done

### Full Lifecycle

```
1. PRD defines the feature          .claude/PRD.md or .claude/PRD-*.md
                                    (version-controlled, holistic spec)
   |
   v
2. /plan-feature creates:
   - Plan file                      .agents/plans/{name}.md
                                    (detailed implementation guide)
   - GitHub feature issue            As sub-issue of Phase Epic
     with AC checkboxes             (status tracking)
   - Task sub-issues (optional)     Under the feature issue
                                    (granular progress)
   |
   v
3. /execute reads the plan file     Implements step by step
   - Moves board item to            "In Progress"
     "In Progress"
   - Checks off AC checkboxes        As each step completes
     as steps complete
   |
   v
4. /commit commits the code
   - Comments on related issues     With commit hash
   - Checks off AC checkboxes       In issue body
   - Closes issues if all AC met    With reference to commit
   - Board auto-updates to Done     Via automation
```

### Quick fixes and bugs

Not every change needs a plan file. For small bugs and quick fixes:

```
1. Pick an issue from the board
2. Implement the fix
3. /commit (links to the issue, closes if complete)
```

---

## 6. Issue Creation Checklist

Every time a GitHub issue is created (by any command or manually), complete these steps:

### Pre-creation: Deduplication & parent lookup

Before creating any issue, always run these checks:

1. **Search for duplicates.** Query open issues for overlapping scope:

   ```bash
   gh issue list --repo nicholasmartin/claude-workflow-template --state open --json number,title,labels --limit 200 --jq '.[] | "#\(.number): \(.title)"'
   ```

   If an existing issue covers the same work, update it instead of creating a new one.

2. **Find the parent epic.** If the work belongs to a phase or epic, query its sub-issues to confirm the issue doesn't already exist there:
   ```bash
   gh api graphql -f query='query { repository(owner: "nicholasmartin", name: "claude-workflow-template") { issue(number: EPIC_NUM) { subIssues(first: 50) { nodes { number title } } } } }' --jq '.data.repository.issue.subIssues.nodes[]'
   ```

### The canonical path: create-issue.sh

One call performs every required step (create + labels + board add + Status/Priority/Phase fields + optional epic link):

```bash
./.claude/scripts/create-issue.sh --title "..." --body-file <path> \
  --labels "phase:1,type:feature,priority:high" \
  --phase "Phase 1" --priority High --status Backlog --parent <epic-number>
```

Rules the script enforces (and that still apply if an issue is ever created manually):

1. Every issue goes on the project board — labels alone do not set board fields
2. Status is always set (Backlog for new issues unless specified)
3. Priority is always set
4. Every issue with a Phase field must be linked to its epic (`--parent`)
5. Board moves later use `./.claude/scripts/move-issue.sh <number> <status>`

### Field IDs Reference

<!-- These IDs are populated by /init-project during setup -->

| Field    | Field ID                         | Option IDs                                                   |
| -------- | -------------------------------- | ------------------------------------------------------------ |
| Status   | `PVTSSF_lAHOAC3aXM4BdVs6zhX37pk`            | Backlog: `5bc12968`, Ready: `99ecc1d7`, In Progress: `0e4738bd`, Done: `43f67a5a` |
| Phase    | `PVTSSF_lAHOAC3aXM4BdVs6zhX37r4`             | Phase 1: `641b0bf7`, Phase 2: `f45eadc2`, Phase 3: `130d8ae1`, Phase 4: `1e65766f`, Phase 5: `0e55d6cf`, Phase 6: `c9c4e3db`                             |
| Priority | `PVTSSF_lAHOAC3aXM4BdVs6zhX37sw`          | Low: `4d7f44bd`, Medium: `310a25b0`, High: `1f398a02`, Critical: `1620f2b7` |

### Under the hood: what create-issue.sh does

For reference (and for cases the script doesn't cover), the raw sequence:

```bash
# 1. Create issue
ISSUE_URL=$(gh issue create --repo nicholasmartin/claude-workflow-template \
  --title "Feature title" \
  --label "phase:1,type:feature,priority:high" \
  --body "...")

# 2. Get issue node ID
ISSUE_NUM=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')
ISSUE_ID=$(gh api graphql -f query='query { repository(owner: "nicholasmartin", name: "claude-workflow-template") { issue(number: '$ISSUE_NUM') { id } } }' --jq '.data.repository.issue.id')

# 3. Add to project board
ITEM_ID=$(gh api graphql -f query="mutation { addProjectV2ItemById(input: { projectId: \"PVT_kwHOAC3aXM4BdVs6\", contentId: \"$ISSUE_ID\" }) { item { id } } }" --jq '.data.addProjectV2ItemById.item.id')

# 4. Set fields (Phase, Priority) in a single mutation
gh api graphql -f query="mutation {
  phase: updateProjectV2ItemFieldValue(input: { projectId: \"PVT_kwHOAC3aXM4BdVs6\", itemId: \"$ITEM_ID\", fieldId: \"PVTSSF_lAHOAC3aXM4BdVs6zhX37r4\", value: { singleSelectOptionId: \"<PHASE_OPTION_ID>\" } }) { projectV2Item { id } }
  priority: updateProjectV2ItemFieldValue(input: { projectId: \"PVT_kwHOAC3aXM4BdVs6\", itemId: \"$ITEM_ID\", fieldId: \"PVTSSF_lAHOAC3aXM4BdVs6zhX37sw\", value: { singleSelectOptionId: \"<PRIORITY_OPTION_ID>\" } }) { projectV2Item { id } }
}"

# 5. Add as sub-issue of Phase Epic (if applicable)
gh api graphql -f query="mutation { addSubIssue(input: { issueId: \"<EPIC_NODE_ID>\", subIssueId: \"$ISSUE_ID\" }) { issue { number } subIssue { number } } }"
```

---

## 7. Slash Command Integration

Each slash command interacts with GitHub in specific ways:

### /plan-feature

- **Reads:** PRD files, open issues, project board state
- **Creates:** Plan file in `.agents/plans/`, GitHub issue (as sub-issue of Phase Epic), optional task sub-issues
- **Updates:** Adds issue to project board, applies labels, sets board fields (Phase, Priority per section 6)

### /execute

- **Reads:** Plan file (passed as argument)
- **Updates:** Moves board item to "In Progress", checks off AC in issue body as steps complete
- **Post-execution:** Comments on issue with summary, notes readiness for `/commit`

### /commit

- **Reads:** Open issues list to find related issues
- **Updates:** Comments on related issues with commit hash, checks off completed AC, closes issues when all AC met
- **AI context tracking:** When staged files include AI context assets (`.claude/rules/`, `.claude/commands/`, `.claude/docs/`, `.claude/skills/`, `CLAUDE.md`, `.claude/workflow.md`), a `Context:` section is appended to the commit body describing what changed and why.

### /continue

- **Reads:** Project board state, open issues, git status (auto-gathered via `.claude/scripts/board-state.sh` inline bash)
- **Purpose:** Resume work by showing current state and suggesting next tasks

### /status

- **Reads:** Project board state, open/closed issues, git log (auto-gathered via `.claude/scripts/board-state.sh` inline bash)
- **Purpose:** Progress report across all phases

### /create-prd

- **Creates:** PRD file in `.claude/` directory
- **Does not interact with GitHub** (PRDs are repo files, not issues)

---

## 8. Hook Layer (Deterministic Validation)

Validation conditions live in the harness, not in prompt prose. The agent supplies judgment (fixes, decisions); code supplies the triggers and the pass/fail checks. Configured in `.claude/settings.json`, implemented in `.claude/hooks/`.

### The Three Tiers

| Tier | Script | Trigger | Cost | Fail behavior |
| ---- | ------ | ------- | ---- | ------------- |
| **Per-edit** | `post-edit-lint.sh` | `PostToolUse` on Write\|Edit | ~ms (single file) | **Advisory** — exit 2 feeds stderr to the agent as feedback; the edit is never undone. Mid-flight breakage is legitimate. |
| **Per-turn** | `stop-validate.sh` | `Stop` (turn ending) | seconds (incremental) | **Blocking** — exit 2 prevents the turn from ending; stderr becomes the agent's fix instructions. |
| **Per-ship** | `pre-commit-scan.sh` | invoked by `/commit` (+ `.husky/pre-commit` on JS repos) | ~ms (staged files) | **Warn** — always exits 0; `/commit` relays findings and asks the user whether to proceed. |

### What each tier checks

- **Per-edit:** `.sh` → `bash -n`; `.ts/.tsx/.js/.jsx` → single-file `eslint --cache` (note: add `.eslintcache` to `.gitignore`). Other extensions skip instantly.
- **Per-turn:** `tsc --noEmit --incremental` when `tsconfig.json` exists; then the project-local battery (below).
- **Per-ship:** staged files scanned for `TODO/FIXME/HACK/XXX`, empty function bodies, empty `catch` blocks, `.only`/`.skip` in test files.

### Design rules

- **Graceful degradation:** every check first detects its tool (`package.json` + `npx --no-install`); missing tooling means silent exit 0, never an error. The template is language-agnostic.
- **Cross-file checks belong to the Stop tier** (tsc can't meaningfully check one file); single-file checks belong to the per-edit tier. Test suites are in neither by default — too slow for a hook timeout; put them in the plan's validation commands or opt in via the local battery.
- **Loop guard:** `stop-validate.sh` exits 0 when `stop_hook_active` is true (Claude Code also force-overrides after 8 consecutive blocks).
- **Hooks run from the launch directory**, not the project root — scripts resolve paths via `$CLAUDE_PROJECT_DIR`.

### Extension point: the project-local battery

Create `.claude/hooks/validate-local.sh` (executable, exit non-zero on failure) to add project-specific checks to the Stop tier — migrations sanity, fast test subsets, custom invariants. It is intentionally NOT part of the template: it belongs to each project and survives template syncs.

### Contracts commands rely on

- `/execute` step 3: per-edit feedback arrives automatically — the command no longer instructs manual verification.
- `/execute` step 5: the Stop battery is unskippable — the command only adds the plan's project-specific validation commands.
- `/commit`: runs `pre-commit-scan.sh` and owns the warn-and-ask conversation.

Changes to any hook script go through the `workflow` skill and must update this section in the same change.

---

## 9. Key Decisions and Rationale

### Why one project instead of multiple?

Views within a single project provide the same visual separation as multiple projects (Bugs view, Backlog view, Active Work view) without the downsides: no status sync issues, no duplicate field configuration, no maintenance overhead, unified filtering across all work.

### Why keep PRDs as files instead of moving them to issues?

PRDs are long-form holistic documents covering architecture, security, database schema, and cross-feature dependencies. They benefit from version control (git history), PR review process, and structured document format (TOC, headings). Issues lack edit history and struggle with long-form content.

### Why keep plan files instead of putting everything in issues?

Plan files contain code patterns with file:line references, import statements, validation commands, and implementation context that would be unwieldy in an issue body. They're the "how to build" guide that an execution agent needs for one-pass implementation. Issues track "what" and "status."

### Why use sub-issues instead of just labels?

Sub-issues provide automatic progress tracking (the Epic shows "11/21 complete"), hierarchy visualization in the project board, and structural relationships between work items. Labels only filter; they don't roll up progress.

---

## 10. Context Loading: 3-Tier System

This project uses progressive context disclosure to keep the context window focused on what matters for the current task.

### Tier 1: Global Rules (always loaded)

- **`CLAUDE.md`** at project root. Contains project overview, tech stack, structure, naming conventions, decision protocol, writing style, and scope enforcement. Kept under 200 lines.

### Tier 2: Path-Scoped Rules (auto-loaded when relevant files are touched)

- **`.claude/rules/*.md`** files with `paths:` frontmatter. Claude Code automatically loads these when the agent reads or edits files matching the path pattern. No manual action needed.

### Tier 3: On-Demand Reference (loaded explicitly when needed)

**Scout-friendly docs** (`.claude/docs/`): each file has a structured header (Purpose, When to use, Size). A sub-agent reads the header to determine relevance before loading the full document. This prevents wasting context on irrelevant material.

**Other Tier 3 resources:**

- **`.claude/PRD.md`** and supplemental PRDs for feature specs
- **`.agents/plans/*.md`** for implementation plans
- **`.claude/workflow.md`** for project management process

When working on a task, prefer reading only the relevant sections of Tier 3 docs rather than loading entire files. For `.claude/docs/`, read the header first and load the full doc only when the feature touches that area.

---

## 11. Changing This Workflow

Use the `/workflow` skill when modifying this system. It ensures all related pieces get updated together:

- This document (`.claude/workflow.md`)
- Slash commands in `.claude/commands/`
- Hooks (`.claude/settings.json`, `.claude/hooks/*.sh`)
- Plumbing scripts (`.claude/scripts/*.sh` — board-state, move-issue, create-issue)
- CLAUDE.md rules
- GitHub Project fields, views, and automations
- Memory files

Never update one piece in isolation. A workflow change typically touches 2-4 of these components.
