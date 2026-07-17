# {{PROJECT_NAME}} Workflow: GitHub-Driven Project Management

**Version:** 1.0
**Status:** Active

This document defines how {{PROJECT_NAME}} manages work through GitHub Issues, Projects, and Claude Code slash commands. It is the single reference for the workflow system and should be updated whenever the process changes.

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

- **Project:** {{PROJECT_NAME}} Roadmap (#{{PROJECT_NUMBER}})
- **Project ID:** `{{PROJECT_ID}}`
- **Repo:** `{{REPO_OWNER}}/{{REPO_NAME}}`

### Custom Fields

| Field             | Type          | Values                                  | Purpose                                                             |
| ----------------- | ------------- | --------------------------------------- | ------------------------------------------------------------------- |
| **Status**        | Single select | Backlog, Ready, In Progress, In Review, Done | Workflow state ("In Review" = PR open, awaiting review — set by `/pr`, resolved by `/continue` reconcile) |
| **Phase**         | Single select | Phase 1-N (add new phases as needed)    | Groups work by development phase                                    |
| **Priority**      | Single select | Low, Medium, High, Critical             | Importance ranking                                                  |

### Views

| View            | Layout                    | Filter                       | Purpose                                         |
| --------------- | ------------------------- | ---------------------------- | ----------------------------------------------- |
| **Epics**       | Table (hierarchy enabled) | `has:phase`                  | Phase-level overview with expandable sub-issues |
| **Bugs**        | Board                     | `label:type:bug`             | All bugs, grouped by status                     |
| **Active Work** | Board (by Status)         | `status:Ready,"In Progress","In Review"` | Daily working view, no backlog noise            |
| **Backlog**     | Board                     | `status:Backlog`             | Everything not yet started                      |

### Automations

| Automation   | Trigger                   | Action               |
| ------------ | ------------------------- | -------------------- |
| Auto-add     | New issue created in repo | Add to project board |
| Item closed  | Issue closed              | Set Status to Done   |
| Auto-archive | Item in Done for 14+ days | Archive item         |

> **Automations are optional UI configuration** — they must be enabled manually in the project's ⚙ Workflows settings (`/init-project` Step 8 prompts this) and cannot be created or verified via the API. **No command relies on them:** `/commit` moves closed items to Done explicitly via `move-issue.sh`. When enabled, automations are a redundant safety net covering closes that happen outside `/commit` (UI, raw `gh issue close`).

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
| **Worktree** | `worktree:<name>` (dynamic — created/removed by `claim-issue.sh`, never pre-created)             | Session ownership claim (see section 10) |

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
   - ON THE DEFAULT BRANCH:         Closes issues if all AC met,
                                    moves board to Done (move-issue.sh),
                                    releases claims
   - ON A FEATURE BRANCH:           Never closes — work hasn't landed yet.
                                    Points at the ship step below.
   |
   v
5. THE SHIP STEP (branch work only) — pick per branch, at ship time:

   /merge (local ending)            Lands the branch on the default branch
   - branch-protection guard        (protected -> redirected to /pr)
   - git merge --no-ff, push
   - closes issues, board -> Done, releases claim
   - branch/worktree kept by default (deletion is explicit)

   /pr (remote ending)              Opens a pull request
   - board -> "In Review"           Issue stays open, claim stays held
   - Closes #N fires when the PR    is merged by a reviewer
   - /continue reconcile afterwards: pull, board -> Done, release claim,
     stack-aware branch GC
```

**The governing invariant: an issue closes only when its work reaches the default branch**
— via `/commit` on that branch, via `/merge`, or via a merged PR. Nothing
closes issues from an unmerged feature branch (escape hatch: `/commit --close`).

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
   gh issue list --repo {{REPO_OWNER}}/{{REPO_NAME}} --state open --json number,title,labels --limit 200 --jq '.[] | "#\(.number): \(.title)"'
   ```

   If an existing issue covers the same work, update it instead of creating a new one.

2. **Find the parent epic.** If the work belongs to a phase or epic, query its sub-issues to confirm the issue doesn't already exist there:
   ```bash
   gh api graphql -f query='query { repository(owner: "{{REPO_OWNER}}", name: "{{REPO_NAME}}") { issue(number: EPIC_NUM) { subIssues(first: 50) { nodes { number title } } } } }' --jq '.data.repository.issue.subIssues.nodes[]'
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
| Status   | `{{STATUS_FIELD_ID}}`            | Backlog: `{{STATUS_BACKLOG_ID}}`, Ready: `{{STATUS_READY_ID}}`, In Progress: `{{STATUS_IN_PROGRESS_ID}}`, Done: `{{STATUS_DONE_ID}}` |
| Phase    | `{{PHASE_FIELD_ID}}`             | (populated as phases are created)                             |
| Priority | `{{PRIORITY_FIELD_ID}}`          | Low: `{{PRIORITY_LOW_ID}}`, Medium: `{{PRIORITY_MEDIUM_ID}}`, High: `{{PRIORITY_HIGH_ID}}`, Critical: `{{PRIORITY_CRITICAL_ID}}` |

### Under the hood: what create-issue.sh does

For reference (and for cases the script doesn't cover), the raw sequence:

```bash
# 1. Create issue
ISSUE_URL=$(gh issue create --repo {{REPO_OWNER}}/{{REPO_NAME}} \
  --title "Feature title" \
  --label "phase:1,type:feature,priority:high" \
  --body "...")

# 2. Get issue node ID
ISSUE_NUM=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')
ISSUE_ID=$(gh api graphql -f query='query { repository(owner: "{{REPO_OWNER}}", name: "{{REPO_NAME}}") { issue(number: '$ISSUE_NUM') { id } } }' --jq '.data.repository.issue.id')

# 3. Add to project board
ITEM_ID=$(gh api graphql -f query="mutation { addProjectV2ItemById(input: { projectId: \"{{PROJECT_ID}}\", contentId: \"$ISSUE_ID\" }) { item { id } } }" --jq '.data.addProjectV2ItemById.item.id')

# 4. Set fields (Phase, Priority) in a single mutation
gh api graphql -f query="mutation {
  phase: updateProjectV2ItemFieldValue(input: { projectId: \"{{PROJECT_ID}}\", itemId: \"$ITEM_ID\", fieldId: \"{{PHASE_FIELD_ID}}\", value: { singleSelectOptionId: \"<PHASE_OPTION_ID>\" } }) { projectV2Item { id } }
  priority: updateProjectV2ItemFieldValue(input: { projectId: \"{{PROJECT_ID}}\", itemId: \"$ITEM_ID\", fieldId: \"{{PRIORITY_FIELD_ID}}\", value: { singleSelectOptionId: \"<PRIORITY_OPTION_ID>\" } }) { projectV2Item { id } }
}"

# 5. Add as sub-issue of Phase Epic (if applicable)
gh api graphql -f query="mutation { addSubIssue(input: { issueId: \"<EPIC_NODE_ID>\", subIssueId: \"$ISSUE_ID\" }) { issue { number } subIssue { number } } }"
```

---

## 7. Slash Command Integration

Each slash command interacts with GitHub in specific ways:

### /plan-feature

- **Reads:** PRD files, open issues, project board state
- **Spawns:** three concurrent research scouts — codebase patterns, external research, testing patterns (see section 9, Subagent Layer)
- **Creates:** Plan file in `.agents/plans/` (including an Integration Contracts section), GitHub issue (as sub-issue of Phase Epic), optional task sub-issues
- **Updates:** Adds issue to project board, applies labels, sets board fields (Phase, Priority per section 6)

### /execute

- **Reads:** Plan file (passed as argument)
- **Spawns:** one task verifier per completed task + a final Observable-Truths verifier (see section 9, Subagent Layer)
- **Updates:** Moves board item to "In Progress", claims the issue (`claim-issue.sh` — see section 10), checks off AC in issue body as steps complete
- **Post-execution:** Comments on issue with summary (including verifier verdicts), notes readiness for `/commit`

### /execute-team

- **Reads:** Plan file (passed as argument), especially its Integration Contracts section
- **Spawns:** teammate agents (2–5) via the experimental agent-teams feature (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) — the lead distributes contract slices and coordinates; falls back to `/execute` with a clear message when the flag is unset (see section 9, Subagent Layer)
- **Updates:** Moves board item to "In Progress" via `move-issue.sh`, claims the issue (`claim-issue.sh` — see section 10), checks off AC in issue body
- **Post-execution:** Comments a per-agent summary; leaves the issue open — closing happens at the ship step (see section 5)

### /execute-isolated

- **Reads:** Plan file (passed as argument) — read in full **before** entering the worktree (worktrees branch from the remote default branch; an uncommitted plan file won't exist inside)
- **Spawns:** whatever the plan's recommended executor spawns — `/execute`'s verifier roster by default, or `/execute-team`'s teammates when the plan recommends the team executor and the agent-teams flag is set (flag unset → single-agent `/execute` inside the same worktree)
- **Updates:** Moves board item to "In Progress" via `move-issue.sh`, claims the issue for the run's worktree (`claim-issue.sh <N> claim <slug>` — see section 10)
- **Post-execution:** `/commit` runs on the worktree branch (comments + AC only — no close off the default branch), then the command **ends at the commit seam**: branch and worktree kept, issue open, claim held. It reports the two ship endings — `/merge` or `/pr` — and stops. Rollback path: `ExitWorktree (remove)` + claim release — the main tree is never touched
- **Fallback:** falls back to plain `/execute` with a clear message when worktree tools are unavailable

### /hotfix

- **Reads:** Issue body, if an issue number was given (an issue is optional — never created)
- **Updates:** Moves board item **Status** to "In Progress" via `move-issue.sh` — Status only, never the Phase field; claims the issue (`claim-issue.sh` — see section 10)
- **No plan file, no subagents:** speed-first single agent; hands off to `/commit` with a `fix:` tag

### /bug

- **Reads:** Issue body **and comments** (`gh issue view --comments`) — the issue is the repro source
- **Contract:** a failing repro (test, or recorded manual repro) must exist **before** any fix is applied
- **Updates:** Moves board item to "In Progress" via `move-issue.sh`, claims the issue (`claim-issue.sh` — see section 10), checks off satisfied AC, comments repro + fix summary; leaves the issue open for `/commit`

### /chore

- **Does not interact with GitHub** (like `/create-prd`) — no issue created, linked, or closed; no board calls; no plan file; no subagents
- **Post-execution:** hands off to `/commit` with a `chore:` (or `docs:`) tag; `/commit`'s issue step naturally no-ops

### /plan-hotfix

- **Reads:** Issue body if a number was given, plus directly implicated files only
- **Creates:** Minimal plan file `.agents/plans/hotfix-<slug>.md` (≤40 lines) — no board writes

### /plan-bug

- **Reads:** Issue body + comments, referenced logs/traces, implicated code paths
- **Creates:** Minimal plan file `.agents/plans/bug-<issue>-<slug>.md` (≤80 lines) with a failing-test-first task order — no board writes

### /commit

- **Reads:** Open issues list to find related issues
- **Updates:** Comments on related issues with commit hash, checks off completed AC. **Closing is gated on the default branch:** on it, closes issues when all AC met — and moves each closed item's board Status to Done via `move-issue.sh` (the "item closed" automation is optional and never relied upon), then releases each closed issue's ownership claim via `claim-issue.sh <N> release` (see section 10). On a feature branch: never closes/moves/releases — points at `/merge` / `/pr` instead (escape hatch: `/commit --close`).
- **AI context tracking:** When staged files include AI context assets (`.claude/rules/`, `.claude/commands/`, `.claude/docs/`, `.claude/skills/`, `CLAUDE.md`, `.claude/workflow.md`), a `Context:` section is appended to the commit body describing what changed and why.

### /merge

- **Reads:** current branch state; the issue(s) the branch implements (plan file or ask)
- **Guards:** refuses on the default branch; requires a clean tree; **branch-protection guard** — `gh api repos/<o>/<r>/branches/<default> --jq .protected` (read-access-safe, reflects rulesets; fail-safe: API failure = assume protected) → protected repos are redirected to `/pr` before anything mutates
- **Does:** `ExitWorktree (keep)` if needed, serialized `git merge --no-ff`, push — the local ship ending
- **Updates:** comments landing hash, checks off AC, closes issues when AC met, board → Done via `move-issue.sh`, releases claim via `claim-issue.sh`
- **Never:** auto-resolves conflicts, force-pushes, or deletes branches/worktrees without an explicit yes (default: keep — `/continue` GCs later)

### /pr

- **Reads:** current branch state; the issue the branch implements (plan file or ask)
- **Does:** pushes the branch, opens the PR (`--reviewer`, `--draft` passthrough; duplicate-PR is reported, not an error) with `Closes #<issue>` in the body — the remote ship ending. **Never merges** (no `gh pr` merge subcommand — merging is the reviewer's call)
- **Updates:** board → "In Review" via `move-issue.sh`, comments the PR URL on the issue. Issue stays open, claim stays held, branch + worktree stay alive (review feedback lands in place; stack follow-up work on top in the same worktree)
- **Afterwards:** the PR merge closes the issue via `Closes #N`; `/continue`'s reconcile finishes the bookkeeping (see below)

### /continue

- **Reads:** Project board state, open issues, git status + `git worktree list` + a **merged-PR probe** over local branches (auto-gathered via `.claude/scripts/board-state.sh` + inline bash)
- **Reconciles (Step 2):** for each local branch whose PR merged upstream — pulls the default branch, board → Done + claim release (always, even when `Closes #N` already closed the issue), then **stack-aware** branch GC: never deletes a branch with local descendants (offers `git rebase --onto` instead); otherwise consent-gated `git branch -D` (squash-merges defeat `-d`; the PR's merged state is the authority), worktree removal first
- **Purpose:** Resume work by showing current state and suggesting next tasks — claim-aware: surfaces `worktree:*` ownership, skips issues claimed by other sessions, flags stale claims (see section 10)

### /status

- **Reads:** Project board state, open/closed issues, git log + `git worktree list` (auto-gathered via `.claude/scripts/board-state.sh` inline bash)
- **Purpose:** Progress report across all phases, including session-claim ownership (report-only — see section 10)

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

## 9. Subagent Layer (Scaled Compute)

Agent-heavy phases fan work out to subagents via the `Agent` tool. The main session keeps the judgment work (clarification, synthesis, decisions); subagents do isolated retrieval and independent verification. The exact prompt specs live in the command files — this section is the system-level contract.

### Roster

| Command | Subagent | Type | Purpose | Returns |
| ------- | -------- | ---- | ------- | ------- |
| `/plan-feature` | Codebase-patterns scout | `Explore` | Structure, similar implementations, conventions, integration points, anti-patterns | Report with file:line evidence + verbatim snippets |
| `/plan-feature` | External-research scout | `general-purpose` | Library versions, official docs with anchors, gotchas, breaking changes | Links + "verified facts" list |
| `/plan-feature` | Testing-patterns scout | `Explore` | Test framework, exemplar tests, runnable validation commands, `.claude/docs/` relevance | Exemplars with line refs + exact commands |
| `/execute` | Task verifier (one per task) | `Explore` | Independently confirms a task's VERIFY/DONE claims after its VALIDATE passes | `VERDICT: PASS` or `VERDICT: FAIL — <evidence>` |
| `/execute` | Observable-Truths verifier | `Explore` | Confirms every plan-level Observable Truth before the output report | Per-truth PASS/FAIL with evidence |
| `/execute-team` | Teammate agents (2–5) | agent-teams (experimental) | Parallel component builds against contract slices, exclusive file ownership | Contract-conformant components + cross-review notes |

### Design Rules

- **Parallelism is explicit:** concurrent subagents are spawned as multiple `Agent` calls in ONE message — prose that lists them as sequential steps serializes them.
- **Prompts are self-contained:** subagents see none of the parent conversation. Every prompt restates the feature, constraints, and the required report format.
- **Evidence, not vibes:** scout reports must carry file:line evidence; the main session spot-checks load-bearing claims before building on them.
- **Judgment stays home:** ambiguity clarification happens *before* the fan-out (scout work is wasted otherwise); synthesis and plan writing stay in the main session.
- **Scouts are read-only by contract:** every scout prompt explicitly forbids creating or modifying files — `general-purpose` scouts carry write tools, so the prompt is the guard. A scout's report is its only deliverable.
- **Type selection:** `Explore` for read-only research (fast; skips CLAUDE.md — tell it to read project rules when they matter); `general-purpose` when the task needs full tooling or project-rule context.
- **Verifiers report, never repair:** the builder stays the only writer. A verifier returns a verdict; the builder fixes and re-verifies. **Verdict gate:** Final Validation cannot start with outstanding or failed verdicts.
- **Hooks check conditions, verifiers check claims:** the Hook Layer (section 8) owns deterministic pass/fail (lint, typecheck, drift); verifiers own judgment about whether a task's claimed outcome actually holds. Neither replaces the other.
- **Light variants spawn no subagents by design:** `/hotfix`, `/chore`, and `/bug` are single-agent on purpose — weight-matching is the feature. (`/plan-bug` may spend at most one `Explore` scout, stated explicitly.)
- **Worktree lifecycle is never delegated:** `/execute-isolated` owns enter/exit/merge in the wrapping session — teammates and subagents never call `EnterWorktree`/`ExitWorktree` (subagents cannot call `ExitWorktree` at all). It adds no new subagent types of its own; it reuses whichever executor roster the plan recommends.

### The Integration Contracts Convention

Every plan produced by `/plan-feature` contains an `## INTEGRATION CONTRACTS` section. For multi-component features it is the authoritative interface definition and must meet this quality bar:

1. Interface URLs exact, **including trailing slashes**
2. Data shapes as **explicit JSON, not prose**, with flat-vs-nested envelopes called out
3. All event/streaming types documented with exact JSON
4. Error responses specified per failure mode (404 body, 422 body, ...)
5. State/storage semantics explicit (e.g., accumulated vs per-chunk)

Plus: component file-ownership boundaries (owns / must-not-touch) and a cross-cutting-concerns table where each concern has **exactly one owner**. Single-component plans state "Single-component feature — no cross-component contracts." explicitly. The consumer is any multi-component executor — the team-based executor is `/execute-team`, which reads this section, confirms completeness, and hands each teammate its contract slice; the section also sharpens single-agent execution.

Changes to scout/verifier prompt specs in command files go through the `workflow` skill and must update this section in the same change.

---

## 10. Coordination Layer (Cross-Session)

Multiple Claude Code sessions — one per terminal, each typically in its own git
worktree — coordinate through GitHub as a **shared blackboard**. `gh` always hits
the remote, so board Status, labels, and comments are visible from every worktree
by construction; the working trees stay isolated, the coordination state does not.

### Ownership claims

A **claim** is a dynamic `worktree:<name>` label on an issue, managed by
`.claude/scripts/claim-issue.sh`:

- **Claim identity:** the worktree slug (`worktree:level-5-coordination`), or
  `main` for the main checkout. At most one main-checkout execution session runs
  at a time — that is the operator's job, not the tooling's.
- **Claim at pickup:** every issue-linked executor (`/execute`, `/execute-team`,
  `/execute-isolated`, `/hotfix`, `/bug`) claims right after moving the item to
  "In Progress". Planning commands do **not** claim — plans are read-mostly and
  live in the main tree.
- **Visible everywhere free of charge:** claims are labels, so they arrive in
  `board-state.sh` output (issues *and* board items) with zero extra API calls.
- **Release — happens at the ship step, where the work lands:** `/commit`
  releases claims on issues it closes (default branch only); `/merge` releases
  after landing; `/continue`'s reconcile releases when a PR has merged
  upstream. `/execute-isolated` ends with the claim **deliberately held** (the
  branch is committed but not landed — PR-parked branches keep their claim by
  design) and releases only on rollback/abandon. `release` also deletes the
  label object once no open issue carries it (self-cleaning — the taxonomy row
  in section 4 documents a *pattern*, not a fixed label set).

### Collision rule

GitHub has no compare-and-swap: two sessions *can* both "successfully" add a
claim. `claim-issue.sh` therefore re-reads the issue after writing; if more than
one `worktree:*` label is present, the **later writer backs off** (removes its
label, exits 3 with `CLAIM COLLISION`). The executor stops and the operator
routes the session elsewhere.

### Stale claims

Sessions die; worktrees get deleted without ceremony. A claim is **stale** when
its worktree is absent from `git worktree list` and the claim isn't `main`.
`/continue` and `/status` flag stale claims; only `/continue` may clear one
(`claim-issue.sh <N> release`) and **only with the user's consent** — never
silently take over claimed work.

---

## 11. Key Decisions and Rationale

### Why one project instead of multiple?

Views within a single project provide the same visual separation as multiple projects (Bugs view, Backlog view, Active Work view) without the downsides: no status sync issues, no duplicate field configuration, no maintenance overhead, unified filtering across all work.

### Why keep PRDs as files instead of moving them to issues?

PRDs are long-form holistic documents covering architecture, security, database schema, and cross-feature dependencies. They benefit from version control (git history), PR review process, and structured document format (TOC, headings). Issues lack edit history and struggle with long-form content.

### Why keep plan files instead of putting everything in issues?

Plan files contain code patterns with file:line references, import statements, validation commands, and implementation context that would be unwieldy in an issue body. They're the "how to build" guide that an execution agent needs for one-pass implementation. Issues track "what" and "status."

### Why use sub-issues instead of just labels?

Sub-issues provide automatic progress tracking (the Epic shows "11/21 complete"), hierarchy visualization in the project board, and structural relationships between work items. Labels only filter; they don't roll up progress.

---

## 12. Context Loading: 3-Tier System

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

## 13. Changing This Workflow

Use the `/workflow` skill when modifying this system. It ensures all related pieces get updated together:

- This document (`.claude/workflow.md`)
- Slash commands in `.claude/commands/`
- Hooks (`.claude/settings.json`, `.claude/hooks/*.sh`)
- Plumbing scripts (`.claude/scripts/*.sh` — board-state, move-issue, create-issue, claim-issue)
- CLAUDE.md rules
- GitHub Project fields, views, and automations
- Memory files

Never update one piece in isolation. A workflow change typically touches 2-4 of these components.
