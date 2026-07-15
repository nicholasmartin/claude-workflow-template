# Feature: Level 4 — Worktree Isolation (/execute-isolated)

The following plan should be complete, but its important that you validate documentation and codebase patterns and task sanity before you start implementing.

Pay special attention to naming of existing utils types and models. Import from the right files etc.

## Feature Description

A new executor command, `/execute-isolated <path-to-plan>`, that runs a plan inside an isolated git worktree via Claude Code's built-in `EnterWorktree` tool. The session's working directory moves into a fresh checkout under `.claude/worktrees/<name>/`; the middle of the envelope is the plan's recommended executor — `/execute` by default, or `/execute-team` when the plan's NOTES recommend the team executor — and the plan's tasks, verifiers/teammates, and validations all run there; `/commit` lands the work on the worktree branch; the session exits the worktree with `ExitWorktree (keep)`, merges the branch back into the main branch from the main checkout, and cleans up. A failed or abandoned run rolls back with `ExitWorktree (remove)` — the main working tree is never touched.

This is Level 4 of AGENTIC-EVOLUTION.md ("Isolation via worktrees") and Phase 4 of the PRD. It is deliberately thin: **one new command wrapping EnterWorktree** — no new hooks, no new scripts, no board-schema changes. The `worktree:<name>` ownership convention is Level 5, not this level.

## User Story

As a solo developer running multiple Claude Code sessions
I want to execute a plan inside an isolated git worktree
So that two features progress in parallel without file conflicts and a failed run rolls back cleanly

## Problem Statement

Every executor today (`/execute`, `/execute-team`, `/hotfix`, `/bug`, `/chore`) works in the main working tree. Two sessions running concurrently collide on files and half-done state; a failed run leaves the main tree dirty. Throughput is bounded by one working tree (AGENTIC-EVOLUTION.md:48 — "Sandboxing. No worktree/isolation story.").

## Solution Statement

Wrap the existing executor flows in a worktree envelope: gate → board open → enter worktree → run the plan's recommended executor unchanged (`/execute` steps 1–6, or `/execute-team` when the plan recommends it) → `/commit` on the worktree branch → exit (keep) → merge back from the main checkout → clean up. Rollback is `ExitWorktree (remove)`. The command *references* the executors (`Read .claude/commands/execute.md and follow its steps 1–6`) instead of duplicating them — one source of truth per flow, per KISS and the Level 4 spec ("One new command wrapping EnterWorktree"). Worktree lifecycle (enter/exit/merge) always belongs to the wrapping session — teammates and subagents never touch it.

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: Low (markdown-only; live-tool semantics carry the real risk, exercised at the walkthrough)
**Primary Systems Affected**: `template/.claude/commands/`, `template/.claude/workflow.md`, `template/.claude/skills/workflow/SKILL.md`, `template/.claude/commands/init-project.md`, root `CLAUDE.md`, root `.gitignore`
**Dependencies**: Claude Code `EnterWorktree`/`ExitWorktree` tools (recommend ≥ v2.1.208 — earlier versions had real worktree bugs, e.g. subagents running git against the main checkout, fixed 2.1.203/2.1.210)

---

## CONTEXT REFERENCES

### Relevant Codebase Files IMPORTANT: YOU MUST READ THESE FILES BEFORE IMPLEMENTING!

- `template/.claude/commands/execute.md` (all 187 lines) - Why: the flow being wrapped; the new command references its steps 1–6 verbatim-by-pointer; mirror its frontmatter (`description`, `argument-hint: [path-to-plan]`) and its step 0 board-open block (lines 14–18)
- `template/.claude/commands/execute-team.md` (lines 1–56, 216–224) - Why: the structural precedent — an executor variant added in Level 3 with a **feature gate + STOP-with-fallback-to-`/execute`** (lines 43–51) and `disable-model-invocation: true` frontmatter; `/execute-isolated` copies both patterns
- `template/.claude/commands/hotfix.md` (lines 1–51) - Why: light-variant tone contrast; confirms board discipline phrasing ("Status only", "never close issues")
- `template/.claude/workflow.md` (§7 lines 236–308, §9 lines 350–389) - Why: §7 needs a new `### /execute-isolated` entry (slot it after `/execute-team`, line 259); §9's roster/design-rules get a one-line note that `/execute-isolated` reuses `/execute`'s verifiers
- `template/.claude/skills/workflow/SKILL.md` (lines 26–41 read-list, 66–91 checklist) - Why: both enumerations list all 15 command files and must gain `execute-isolated.md` (15 → 16)
- `template/.claude/commands/init-project.md` (line 146 verification loop, line 548 count) - Why: `for cmd in commit continue execute execute-team ...` must gain `execute-isolated`; "15 slash commands configured" → 16
- `CLAUDE.md` (line 63) - Why: "# 15 slash commands" count → 16. **Direct edit — sync never touches root CLAUDE.md**
- `scripts/sync-template.sh` (lines 27–57) - Why: confirms a new `commands/*.md` is auto-discovered and placeholder-filled — no sync changes needed
- `.agents/plans/level-3-weight-matched-command-variants.md` (lines 173–180, 276–280) - Why: task-format exemplar and the canonical final sync+battery closer task
- `.agents/learnings/level-3.md` (headers) - Why: the section template `level-4.md` must follow (gap / file-by-file / information flow / see-it-yourself / watch-out-for / findings / walkthrough log) + companion `level-4-diagram.mmd`

### New Files to Create

- `template/.claude/commands/execute-isolated.md` - The command (worktree envelope around `/execute`)
- `.claude/commands/execute-isolated.md` - GENERATED by `./scripts/sync-template.sh` — never hand-edit
- `.gitignore` (repo root; does not exist yet) - `.claude/worktrees/` entry (official docs tip; keeps worktree dirs out of git status)
- `.agents/learnings/level-4.md` + `.agents/learnings/level-4-diagram.mmd` - Learning-gate deliverables (repo-only, never shipped in template/)

### Relevant Documentation YOU SHOULD READ THESE BEFORE IMPLEMENTING!

- [Claude Code worktrees](https://code.claude.com/docs/en/worktrees)
  - Specific sections: "Choose the base branch", "Clean up worktrees", "Copy gitignored files into worktrees"
  - Why: authoritative semantics — `.claude/worktrees/<name>/` location, base ref default `origin/HEAD` ("fresh") vs `worktree.baseRef: "head"`, exit-time keep/remove rules, `.worktreeinclude`
- [Tools reference](https://code.claude.com/docs/en/tools-reference)
  - Specific section: EnterWorktree / ExitWorktree entries
  - Why: permission behavior (no prompt for new worktrees under `.claude/worktrees/`), path-vs-name restrictions
- [Claude Code CHANGELOG](https://raw.githubusercontent.com/anthropics/claude-code/refs/heads/main/CHANGELOG.md)
  - Specific entries: 2.1.157, 2.1.196–2.1.210
  - Why: version gates for worktree features; basis for the ≥2.1.208 recommendation

### Patterns to Follow

**Frontmatter + argument handling** (execute.md:1-4, execute-team.md:1-5):

```markdown
---
description: Execute an implementation plan inside an isolated git worktree
argument-hint: [path-to-plan]
disable-model-invocation: true
---
```

**Board-open step** (execute.md:14-18 — copy verbatim, plus the never-close guard from execute-team.md:39):

```markdown
- Ask the user which GitHub issue this plan implements (if not obvious from the plan)
- Read the issue body: `gh issue view <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}}`
- Move the board item to "In Progress": `./.claude/scripts/move-issue.sh <NUMBER> "In Progress"`

**Never close issues or move them to Done here — only `/commit` closes issues.**
```

**Feature gate + STOP-with-fallback** (execute-team.md:43-51 — adapt for worktrees):

```markdown
**Worktree gate — check this before anything else.** If the `EnterWorktree` tool is
not available in this session, STOP with:

> Worktree tools are not available (Claude Code ≥ 2.1.208 recommended). Run
> `/execute <plan>` instead — the single-agent executor handles the same plan in
> the main working tree.
```

**Ripple discipline** (SKILL.md guardrail, CLAUDE.md golden rule): never update a command without updating `workflow.md`; never update either without re-running `./scripts/sync-template.sh`.

---

## INTEGRATION CONTRACTS

Single-component feature — no cross-component contracts.

(Everything is markdown in one repo with one owner; the "interfaces" are Claude Code's own tool contracts, documented under Relevant Documentation above.)

---

## OBSERVABLE TRUTHS

- `/execute-isolated` exists in the live installation: `.claude/commands/execute-isolated.md` present, zero unresolved `{{PLACEHOLDER}}` tokens
- The command instructs, in order: worktree gate → plan read *before* entering → board "In Progress" → `EnterWorktree` (name derived from plan slug) → run the plan's recommended executor by reference (`/execute` steps 1–6, or `/execute-team` from its Step 1; team flag unset → `/execute` in the same worktree) → `/commit` on the worktree branch → `ExitWorktree (keep)` → merge from main checkout → cleanup; plus a rollback path via `ExitWorktree (remove)`
- The command states that worktree lifecycle belongs to the wrapping session only — teammates/subagents never call `EnterWorktree`/`ExitWorktree`
- `workflow.md` §7 documents `/execute-isolated` (13 `### /` command entries, up from 12); SKILL.md's two enumerations list 16 command files; init-project's loop and count say 16
- `./scripts/sync-template.sh` exits 0 with "OK: template synced, all placeholders resolved."; `./.claude/hooks/validate-local.sh` exits 0
- **At the walkthrough (PRD Phase 4 validation):** two plans execute in parallel worktrees with zero file conflicts and clean merges; a deliberately aborted run rolls back leaving the main tree untouched

## REQUIRED ARTIFACTS

- [ ] `template/.claude/commands/execute-isolated.md` - the command
- [ ] `.claude/commands/execute-isolated.md` - generated by sync
- [ ] Updated `template/.claude/workflow.md` - §7 entry + §9 note
- [ ] Updated `template/.claude/skills/workflow/SKILL.md` - both enumerations (16 files)
- [ ] Updated `template/.claude/commands/init-project.md` - loop + count
- [ ] Updated `CLAUDE.md` - command count 16 (direct edit)
- [ ] `.gitignore` - `.claude/worktrees/` entry
- [ ] `.agents/learnings/level-4.md` + `level-4-diagram.mmd` - learning gate (HARD GATE)

## KEY LINKS

- PRD: `.claude/PRD.md` §7 Level 4 (lines 212–214), §12 Phase 4 (line 307 — validation: "Two plans executed in parallel worktrees, clean merges", 1 session)
- Roadmap: `AGENTIC-EVOLUTION.md` lines 133–147 (Level 4 spec)
- GitHub issue: Phase 4 epic (created alongside this plan)
- Docs: links under Relevant Documentation above

---

## IMPLEMENTATION PLAN

### Phase A: The command

Create `template/.claude/commands/execute-isolated.md` — the worktree envelope. All worktree-semantics knowledge (base-ref gotcha, merge-back order, rollback) is encoded here and only here.

### Phase B: Ripple updates

workflow.md §7/§9, SKILL.md enumerations, init-project loop + count, CLAUDE.md count, `.gitignore` — the same ripple set Level 3 established (learnings/level-3.md is the checklist).

### Phase C: Sync + validation close

`./scripts/sync-template.sh`, full battery, git-status sanity.

### Phase D: Learning gate (HARD GATE)

`level-4.md` + diagram drafted; live walkthrough runs the PRD's Phase 4 validation (two parallel worktrees, clean merges, one rollback); owner sign-off closes the epic.

---

## STEP-BY-STEP TASKS

IMPORTANT: Execute every task in order, top to bottom. Each task is atomic and independently testable.

### CREATE template/.claude/commands/execute-isolated.md

- **IMPLEMENT**: The worktree envelope command, ~100–130 lines, with these sections in order:
  1. **Frontmatter**: `description: Execute an implementation plan inside an isolated git worktree`, `argument-hint: [path-to-plan]`, `disable-model-invocation: true` (explicit invocation only, like `/execute-team`)
  2. **Intro / When to use**: contrast with `/execute`/`/execute-team` (same flows, isolated tree; use when running plans in parallel terminals or when easy rollback matters — works with either executor). State plainly: "This command works in a **git worktree** using the `EnterWorktree` tool" — the tool's own gating requires explicit worktree instruction; paraphrases like "isolated environment" can make the model hesitate
  3. **Step 1 — Worktree gate**: the STOP-with-fallback block from Patterns to Follow (fallback: `/execute <plan>`; recommend Claude Code ≥ 2.1.208)
  4. **Step 2 — Read the plan FIRST**: read `$ARGUMENTS` in full **before entering the worktree**. GOTCHA made explicit in the command text: worktrees branch from `origin/<default-branch>` by default (`worktree.baseRef: "fresh"`) — an uncommitted or unpushed plan file will NOT exist inside the worktree. After entering, if the plan file is missing, re-create it verbatim from what was read here
  5. **Step 3 — Link to GitHub issue → In Progress**: the board-open block from Patterns to Follow (verbatim), including the never-close guard
  6. **Step 4 — Enter the worktree**: call `EnterWorktree` with `name` = the plan filename slug (e.g. plan `level-5-coordination.md` → name `level-5-coordination`). Note resume semantics: re-using a name resumes that worktree (a clean never-committed one resets to base); to force a fresh tree, pick a suffixed name. Then pre-flight inside the worktree: `git branch --show-current` (expect a worktree branch), `git status --porcelain` (expect clean), and ensure `.claude/worktrees/` is gitignored — `grep -qxF '.claude/worktrees/' .gitignore 2>/dev/null || echo '.claude/worktrees/' >> .gitignore` (self-healing for template users; note this creates a 1-line diff to commit)
  7. **Step 5 — Execute the plan (executor choice)**: pick the executor the plan's NOTES recommend — default `/execute`. (a) **Single-agent**: "Read `.claude/commands/execute.md` and follow its Execution Instructions **steps 1–6 exactly** (skip its step 0 — done above). All of it applies unchanged: pre-flight, task loop, per-task verifiers, verdict gate, final validation, Observable-Truths verifier, deviation rules." (b) **Team**: "Read `.claude/commands/execute-team.md` and follow it **from its Step 1** (skip its Step 0 — done above)." Its feature-flag gate still applies, but inside the worktree the failure mode softens: if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is unset, fall back to (a) *in this same worktree* instead of stopping. Either path: **worktree lifecycle (enter/exit/merge) belongs to this session only — teammates and subagents never call `EnterWorktree`/`ExitWorktree`** (subagents cannot call `ExitWorktree` at all). Do NOT duplicate either flow
  8. **Step 6 — Commit on the worktree branch**: run the `/commit` flow while still inside the worktree (commit lands on the worktree branch; `gh` issue updates work normally — the board is shared state, the tree is not). `/commit` closes issues exactly as it always does
  9. **Step 7 — Exit and merge back**: `ExitWorktree` with `action: "keep"` (NEVER `remove` before merging — remove deletes the branch and the work). Back in the main checkout: confirm the main tree is clean and no other session is mid-merge (two parallel `/execute-isolated` sessions must serialize their merges — ask the user if unsure), then `git merge --no-ff <worktree-branch>`, then clean up: `git worktree remove .claude/worktrees/<name>` and `git branch -d <worktree-branch>`
  10. **Rollback path** (its own short section): to abandon a run, `ExitWorktree` with `action: "remove"`; if it refuses because of uncommitted/unmerged work, confirm with the user before retrying with `discard_changes: true`. The main tree is untouched either way
  11. **Notes**: parallel usage (N terminals × N worktrees — coordination conventions arrive in Level 5); `ExitWorktree` never merges anything — merge-back is always the explicit Step 7; gitignored files (`.env`, `settings.local.json`) are absent in worktrees — point users at `.worktreeinclude` (worktrees docs); session ending while inside a worktree: clean → auto-removed, dirty → keep/remove prompt
- **PATTERN**: gate/fallback execute-team.md:43-51; board-open execute.md:14-18; frontmatter execute-team.md:1-5
- **GOTCHA**: base-ref/plan-file (encoded as Step 2); merge-before-remove ordering (Step 7 vs rollback); the command may use `{{REPO_OWNER}}`/`{{REPO_NAME}}` placeholders freely (sync fills them) but no NEW placeholder tokens (workflow.env has no worktree entries)
- **VALIDATE**: `test -f template/.claude/commands/execute-isolated.md && grep -c 'EnterWorktree' template/.claude/commands/execute-isolated.md` → ≥3; `grep -c 'ExitWorktree' template/.claude/commands/execute-isolated.md` → ≥3; `grep -c 'execute-team' template/.claude/commands/execute-isolated.md` → ≥2; `grep -c 'move-issue.sh' template/.claude/commands/execute-isolated.md` → 1; `grep -c '/execute <plan>' template/.claude/commands/execute-isolated.md` → ≥1; `grep -ci 'never close' template/.claude/commands/execute-isolated.md` → ≥1; `awk '/^````/{n++} END{print n+0}' template/.claude/commands/execute-isolated.md` → 0
- **VERIFY**: reading the file top-to-bottom, the order is gate → plan-read → board → enter → executor-choice-by-reference → commit → exit(keep) → merge → cleanup, with rollback separate; neither `/execute`'s nor `/execute-team`'s flow is duplicated (no task loop, deviation rules, or contract-distribution steps copied in); the team path states the in-worktree flag fallback and the lifecycle-stays-home rule
- **DONE**: file exists, all VALIDATE greps pass, sync not yet run (next tasks)

### UPDATE template/.claude/workflow.md

- **IMPLEMENT**: (1) In §7, add a `### /execute-isolated` entry immediately after the `/execute-team` block (after line 259), matching the established Reads/Spawns/Updates/Post-execution shape: Reads plan file (before entering the worktree); Spawns whatever the plan's recommended executor spawns — `/execute`'s verifier roster by default, or `/execute-team`'s teammates when the plan recommends the team executor and the agent-teams flag is set (flag unset → single-agent `/execute` inside the same worktree); Updates board to "In Progress" via `move-issue.sh`; Post-execution commits on the worktree branch, exits with keep, merges back from the main checkout; falls back to plain `/execute` with a clear message when worktree tools are unavailable. (2) In §9, add one design-rule bullet: worktree lifecycle (enter/exit/merge) is owned by the wrapping session, never by teammates or subagents — `/execute-isolated` adds no new subagent types of its own
- **PATTERN**: the `/execute-team` §7 entry (workflow.md:254-259) is the size and tone target
- **GOTCHA**: keep the entry to the §7 shape — worktree semantics live in the command file, not workflow.md
- **VALIDATE**: `grep -c '^### /' template/.claude/workflow.md` → 13; `grep -c 'execute-isolated' template/.claude/workflow.md` → ≥2
- **VERIFY**: §7 order is /execute → /execute-team → /execute-isolated → /hotfix; §9 bullet present
- **DONE**: both greps pass

### UPDATE template/.claude/skills/workflow/SKILL.md

- **IMPLEMENT**: add `.claude/commands/execute-isolated.md` to the Step 1 read-list (after `execute-team.md`, line 30) and the Step 3 impact-analysis checklist (after line 70)
- **PATTERN**: existing list entries — exact same indentation/format
- **GOTCHA**: there are exactly TWO enumerations; missing one recreates the drift Level 3's learning doc warned about
- **VALIDATE**: `grep -c 'execute-isolated' template/.claude/skills/workflow/SKILL.md` → 2
- **VERIFY**: both the numbered read-list and the checkbox list contain the new file
- **DONE**: grep returns exactly 2

### UPDATE template/.claude/commands/init-project.md

- **IMPLEMENT**: line 146 — add `execute-isolated` to the `for cmd in ...` verification loop (after `execute-team`); line 548 — "15 slash commands configured" → "16 slash commands configured"
- **PATTERN**: the loop's existing space-separated names
- **GOTCHA**: init-project.md is copied verbatim by sync (braces are instructional) — edits appear unchanged at root; the "Ready to Use" list (lines 560–567) is a curated short list that already omits Level 3 variants — leave it alone
- **VALIDATE**: `grep -c 'execute-isolated' template/.claude/commands/init-project.md` → 1; `grep -c '16 slash commands' template/.claude/commands/init-project.md` → 1
- **VERIFY**: loop still one line, names space-separated
- **DONE**: both greps pass

### UPDATE CLAUDE.md (root — direct edit)

- **IMPLEMENT**: line 63: `# 15 slash commands (plan-feature, execute, execute-team, hotfix, bug, chore, ...)` → `# 16 slash commands (...)`
- **PATTERN**: level-3 did the same count bump (learnings/level-3.md — "count line (direct edit; sync never touches it)")
- **GOTCHA**: root CLAUDE.md is NOT generated — edit it directly; do not touch template/.claude/CLAUDE-template.md (it doesn't carry a count)
- **VALIDATE**: `grep -c '16 slash commands' CLAUDE.md` → 1; `grep -c '15 slash commands' CLAUDE.md` → 0
- **VERIFY**: only the count changed on that line
- **DONE**: both greps pass

### CREATE .gitignore (repo root)

- **IMPLEMENT**: new file containing a comment line and `.claude/worktrees/` (official worktrees-doc tip: keeps worktree checkouts out of git status; this repo has no .gitignore today)
- **PATTERN**: none — file doesn't exist
- **GOTCHA**: repo-root file, NOT under template/ — template users get the same protection from the command's self-healing pre-flight grep (execute-isolated.md Step 4) instead
- **VALIDATE**: `grep -qxF '.claude/worktrees/' .gitignore && echo ok` → ok
- **VERIFY**: `git check-ignore .claude/worktrees/foo` exits 0 after the file exists
- **DONE**: both pass

### RUN sync + full battery (Phase C close)

- **IMPLEMENT**: `./scripts/sync-template.sh`; then the full battery; then confirm git status shows exactly the expected new/modified files
- **PATTERN**: level-3 plan's closer task (level-3-weight-matched-command-variants.md:276-280)
- **GOTCHA**: the Stop-hook drift check blocks the turn if sync is skipped after template edits
- **VALIDATE**: `./scripts/sync-template.sh` → "OK: template synced, all placeholders resolved."; `./.claude/hooks/validate-local.sh && echo battery-green` → battery-green; `grep -rn '{{' .claude/commands/execute-isolated.md | grep -vc 'init-project'` → 0
- **VERIFY**: `ls .claude/commands/*.md | wc -l` → 16; `git status --porcelain` lists only: the new command (template + generated), workflow.md ×2, SKILL.md ×2, init-project.md ×2, CLAUDE.md, .gitignore, this plan file
- **DONE**: battery green, file list matches

### CREATE .agents/learnings/level-4.md + level-4-diagram.mmd (Phase D — HARD GATE)

- **IMPLEMENT**: draft `level-4.md` following level-3.md's exact section list (gap this closes / what changed file-by-file / how information flows now / see it yourself / what to watch out for / findings / walkthrough log) + a `level-4-diagram.mmd` showing the envelope: main tree → EnterWorktree → execute flow → commit → ExitWorktree(keep) → merge → cleanup, with the rollback branch. "See it yourself" must script the PRD Phase 4 validation: (a) two terminals, two small real plans, `/execute-isolated` each, confirm zero conflicts and two clean merges; (b) one deliberate abort → `ExitWorktree (remove)` → main tree untouched. The walkthrough also settles the scouts' unverified assumptions live — record in "findings": actual worktree branch name format, whether `$CLAUDE_PROJECT_DIR` points at the worktree root, and whether PostToolUse/Stop hooks fire inside the worktree; if the agent-teams flag is enabled, additionally observe (best-effort, not a gate) that teammate file operations land under the worktree path, not the main checkout
- **PATTERN**: `.agents/learnings/level-3.md` structure; diagram alongside like `level-3-diagram.mmd`
- **GOTCHA**: learning docs are repo-only — never copy into template/; the walkthrough log section is appended DURING the live walkthrough, not pre-written; sign-off is an explicit logged act on the epic (no sign-off → Level 5 planning does not start)
- **VALIDATE**: `test -f .agents/learnings/level-4.md && grep -c '^## ' .agents/learnings/level-4.md` → ≥6; `test -f .agents/learnings/level-4-diagram.mmd && echo ok` → ok
- **VERIFY**: section headers match level-3.md's set; walkthrough log filled in after the live session
- **DONE**: docs exist, walkthrough performed, owner sign-off recorded on the epic

---

## TESTING STRATEGY

No test framework — validation is structural (this is a markdown+bash product), plus a live behavioral walkthrough.

### Unit Tests

N/A. Per-task structural greps (VALIDATE lines above) play this role.

### Integration Tests

The sync + battery closer task: `sync-template.sh` + `validate-local.sh` (placeholder scan, sync-drift, `bash -n`) prove the template↔root integration.

### Edge Cases

Exercised live at the walkthrough, not in CI:
- Plan file uncommitted → must still be present inside the worktree (Step 2 re-materialization)
- `ExitWorktree (remove)` with unmerged commits → must refuse without `discard_changes`, and the command's rollback text must route through user confirmation
- Re-running with the same plan slug → resumes the existing worktree (documented, not prevented)
- Two sessions merging back-to-back → merges serialize in the main checkout without conflict (the PRD's "clean merges")
- Plan recommends `/execute-team` but `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is unset → falls back to single-agent `/execute` inside the same worktree (no STOP; isolation preserved)

---

## VALIDATION COMMANDS

Execute every command to ensure zero regressions and 100% feature correctness.

### Level 1: Syntax & Style

```bash
for f in scripts/*.sh .claude/hooks/*.sh .claude/scripts/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
awk '/^````/{n++} END{print n+0}' template/.claude/commands/execute-isolated.md   # → 0
```

### Level 2: Unit Tests

```bash
# Structural greps — every per-task VALIDATE line above, plus:
grep -c '^### /' template/.claude/workflow.md            # → 13
grep -c 'execute-isolated' template/.claude/skills/workflow/SKILL.md   # → 2
ls .claude/commands/*.md | wc -l                          # → 16 (after sync)
```

### Level 3: Integration Tests

```bash
./scripts/sync-template.sh          # → "OK: template synced, all placeholders resolved."
./.claude/hooks/validate-local.sh && echo battery-green   # → battery-green
grep -rn '{{' .claude/commands/execute-isolated.md        # → no output
```

### Level 4: Manual Validation

At the walkthrough (learning gate): two parallel `/execute-isolated` runs on real small plans → zero conflicts, clean merges; one aborted run → `ExitWorktree (remove)`, main tree untouched; record branch-name format, `$CLAUDE_PROJECT_DIR`, and hook-firing observations in level-4.md findings.

---

## ACCEPTANCE CRITERIA

- [ ] `/execute-isolated <plan>` exists in template/ and the synced root installation, placeholders resolved
- [ ] Command order: gate → plan-read-before-enter → board In Progress → EnterWorktree → recommended executor by reference (`/execute` steps 1–6 or `/execute-team` from Step 1) → `/commit` on worktree branch → ExitWorktree(keep) → merge from main checkout → cleanup
- [ ] Executor choice baked in: `/execute` default; `/execute-team` when the plan recommends it; team flag unset → `/execute` in the same worktree; worktree lifecycle never delegated to teammates/subagents
- [ ] Rollback path documented: ExitWorktree(remove), user-confirmed `discard_changes`, main tree untouched
- [ ] STOP-with-fallback to `/execute` when worktree tools are unavailable (mirrors `/execute-team`'s gate)
- [ ] workflow.md §7 entry (13 command entries) + §9 worktree-ownership bullet; SKILL.md both enumerations at 16; init-project loop + count at 16; CLAUDE.md count at 16; `.gitignore` covers `.claude/worktrees/`
- [ ] Sync green, battery green, no unresolved placeholders
- [ ] Level 4 learning doc + diagram exist; live walkthrough executed the PRD Phase 4 validation (two parallel worktrees, clean merges, one rollback); owner sign-off recorded (HARD GATE — blocks Level 5)

---

## COMPLETION CHECKLIST

- [ ] All tasks completed in order
- [ ] Each task validation passed immediately
- [ ] All validation commands executed successfully
- [ ] Full battery passes (`validate-local.sh`)
- [ ] No unresolved placeholders in generated files
- [ ] Walkthrough confirms live worktree behavior
- [ ] Acceptance criteria all met
- [ ] Board: epic + task sub-issues moved through In Progress → Done by `/commit` only

---

## NOTES

**Executor decision: `/execute` (single-agent).** Single-component feature — one repo, markdown-only, no interface boundaries, empty INTEGRATION CONTRACTS. `/execute-team` would be ceremony without parallelizable components. (Dogfood irony noted: `/execute-isolated` cannot execute its own plan — it doesn't exist yet.)

**Design decisions:**
- **Wrap-by-reference, not copy.** The command points at `/execute`'s steps 1–6 (or `/execute-team` from its Step 1) instead of duplicating them — one source of truth per flow; executor improvements flow through automatically. Precedent: `/execute-team` similarly leans on shared conventions rather than restating them.
- **Executor-agnostic envelope (decided 2026-07-15).** The worktree envelope doesn't care which executor fills the middle, so `/execute-team` is supported by plan recommendation. Two containments make this safe: (1) the team path keeps `/execute-team`'s own flag gate, but softens it in-worktree — flag unset falls back to single-agent `/execute` in the same worktree rather than STOPping (isolation is preserved either way); (2) worktree lifecycle is never delegated — teammates/subagents cannot call `ExitWorktree`, so enter/exit/merge stays with the wrapping session by rule, not just by tooling. Team-in-worktree behavior is unverified live; the walkthrough observes it best-effort if the flag is available, and the fallback chain (`team → single-agent → main-tree /execute`) contains every failure mode.
- **`disable-model-invocation: true`** — entering worktrees relocates the session's working directory; that should never happen because the model auto-picked a command. Explicit invocation only, like `/execute-team`.
- **Merge-back is a command step, not an ExitWorktree feature.** Verified: `ExitWorktree` never merges; `remove` deletes branch + work. The keep → merge → cleanup ordering is the safety-critical part of the command text.
- **Worktree name = plan slug** — deterministic and resumable, and it prefigures Level 5's `worktree:<name>` ownership convention without introducing any label/board changes now (that would be an out-of-scope taxonomy change).
- **No new hooks/scripts/board schema.** The existing hooks are worktree-safe for this repo (`.claude/` is committed, `$CLAUDE_PROJECT_DIR`-relative); board scripts are pure `gh` against the shared remote. The root-only `validate-local.sh` battery will run against the worktree's own checkout inside a worktree — correct behavior, worth observing at the walkthrough.
- **README's command table is out of scope** — it was already not updated for Level 3's variants; syncing it is a separate docs chore, not part of the established ripple set.
- **PRD checkbox convention:** PRD §4 checkboxes for Levels 1–3 remain unchecked (that's the repo's convention — the board tracks completion); leave line 54 alone.

**Risks:**
- `EnterWorktree`/`ExitWorktree` are evolving primitives (PRD risk table row) — contained by the gate + fallback, same containment as `/execute-team`'s flag.
- The team path compounds two experimental mechanics (agent teams × worktrees) — historically fragile (changelog fixes 2.1.203/2.1.210 for subagents running git against the main checkout). Contained by the in-worktree flag fallback and the lifecycle-stays-home rule; observed live at the walkthrough only if the flag is enabled.
- Two scout claims are UNVERIFIED and deliberately deferred to the walkthrough rather than assumed: exact worktree branch-name format, and `$CLAUDE_PROJECT_DIR` resolution inside worktrees (community report says worktree root). Nothing in the command depends on either being one way or the other.

**Confidence score: 9/10** for one-pass implementation (markdown-only, exemplar-rich, every task has structural validation). The residual 1 point is live worktree-tool behavior, which the learning-gate walkthrough exists to exercise.
