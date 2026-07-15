# Feature: Level 5 — Cross-Session Coordination (board as shared blackboard)

The following plan should be complete, but its important that you validate documentation and codebase patterns and task sanity before you start implementing.

Pay special attention to naming of existing utils types and models. Import from the right files etc.

## Feature Description

Level 5 of AGENTIC-EVOLUTION.md / Phase 5 of the PRD. Multiple concurrent Claude Code terminal sessions (each typically in its own git worktree via `/execute-isolated`, plus at most one in the main checkout) coordinate through the GitHub Issues + Projects board — the shared blackboard — so no session ever picks up work another session owns.

The mechanism is an **ownership-claim convention**: when an executor starts work on an issue it adds a dynamic `worktree:<name>` label (the claim), where `<name>` is the worktree slug (or `main` for the main checkout). `/continue` and `/status` become claim-aware: claimed issues are surfaced with their owner and skipped during work selection unless the claim belongs to the current session. `/commit` releases claims when it closes issues. A small plumbing script (`claim-issue.sh`) makes the claim/release mechanics deterministic (labels must be created before they can be added — a verified `gh` gotcha — and a post-claim re-read detects collisions, since GitHub has no compare-and-swap).

Labels were chosen over structured comments as the marker because `board-state.sh` already emits labels for both open issues and board items — `/continue` and `/status` get claim visibility with **zero additional API calls**. See NOTES for the full decision rationale.

## User Story

As a solo developer running 2–3 Claude Code terminals in parallel
I want each session to visibly claim the issue it is working on, and every session to respect others' claims
So that parallel sessions never step on each other's work and I can act as the router in the software-factory model

## Problem Statement

Level 4 delivered isolation (worktrees) but not coordination: two terminals can both run `/continue`, both see the same `Ready` issue, and both start it. Board Status "In Progress" says *someone* is on an issue but not *which session/worktree*, so a resumed session can't tell its own work from another's, and a dead session's claim is indistinguishable from a live one. `/execute-isolated`'s Notes explicitly defer this: "Coordination conventions (worktree ownership labels) arrive in Level 5" (`template/.claude/commands/execute-isolated.md:120-122`).

## Solution Statement

A claim lifecycle layered on the existing board plumbing:

1. **Claim** — every executor's issue-linking step (`move-issue.sh <N> "In Progress"`) gains a sibling call: `claim-issue.sh <N> claim [<name>]`. The script creates the `worktree:<name>` label idempotently (`gh label create --force`), adds it to the issue, then re-reads the issue's labels; if more than one `worktree:*` label is present it removes its own and exits non-zero (collision — earliest claimant keeps the issue).
2. **Respect** — `/continue`'s work-order rules skip issues carrying a `worktree:*` label that doesn't match the current session's worktree; its report and `/status`'s gain claim visibility. `git worktree list` joins the auto-gathered state so stale claims (claimed worktree no longer exists locally) are detected at zero API cost and surfaced to the user.
3. **Release** — `/commit` removes `worktree:*` labels from issues it closes; `/execute-isolated` Step 7 releases after the merge/cleanup. `release` also deletes the label object when no open issue still carries it, so the label list doesn't accumulate dead slugs.

Convention over machinery: no daemon, no lock files, no new command. One ~60-line script, edits to 9 existing command files, one bug fix (`board-state.sh` missing `--limit` — the board is at 28 items and `gh project item-list` silently truncates at 30), and the workflow.md/skill ripple.

## Feature Metadata

**Feature Type**: Enhancement (convention + one plumbing script)
**Estimated Complexity**: Low-Medium
**Primary Systems Affected**: `template/.claude/scripts/`, executor commands, `/continue`, `/status`, `/commit`, `workflow.md`, workflow skill
**Dependencies**: GitHub CLI ≥ 2.46 (already required); no new external dependencies

---

## CONTEXT REFERENCES

### Relevant Codebase Files IMPORTANT: YOU MUST READ THESE FILES BEFORE IMPLEMENTING!

- `template/.claude/commands/execute-isolated.md` (lines 45-51 Step 3 issue→In Progress; 53-68 Step 4 slug derivation; 96-110 Step 7 merge/cleanup; 118-128 Notes) — Why: primary integration point; claim name = the plan slug already derived here; Notes line 120-122 must flip from "arrive in Level 5" to the implemented convention
- `template/.claude/commands/continue.md` (lines 5-11 auto-gather; 15-20 report table; 30-38 work-order rules) — Why: the selection logic that becomes claim-aware
- `template/.claude/commands/status.md` (lines 13-20 auto-gather; report sections after) — Why: claim visibility in the progress report
- `template/.claude/commands/execute.md` (lines 14-18 Step 0) — Why: claim call slots after the `move-issue.sh` line
- `template/.claude/commands/execute-team.md` (lines 31-39 Step 0) — Why: same slot
- `template/.claude/commands/hotfix.md` (lines 18-30 Step 0) — Why: same slot; light-command anatomy pattern
- `template/.claude/commands/bug.md` (lines 12-22 Step 0) — Why: same slot
- `template/.claude/commands/commit.md` (lines 61-76 Post-Commit issue updates; 69-70 close + move Done) — Why: the release point
- `template/.claude/scripts/board-state.sh` (lines 11-15) — Why: labels already in the payload (issues line 11, board line 13); line 13 is the missing-`--limit` bug
- `template/.claude/scripts/move-issue.sh` (whole file, ~35 lines) — Why: the script anatomy `claim-issue.sh` must mirror (header comment, not-runnable-template note, `set -euo pipefail`, `{{REPO_OWNER}}/{{REPO_NAME}}` placeholders, arg validation)
- `template/.claude/scripts/create-issue.sh` (lines 18-29 arg parsing; 52-54 label application) — Why: long-flag parsing convention; label syntax pattern
- `template/.claude/workflow.md` (§4 Labels lines 97-111; §7 command entries 236-316; §9 ends ~398; §10-12 at 402/422/448; line 455 plumbing enumeration) — Why: taxonomy row, per-command entries, new Coordination Layer section, renumbering
- `template/.claude/skills/workflow/SKILL.md` (lines 66-93 impact checklist; 155-163 guardrails) — Why: checklist + a new coordination guardrail
- `scripts/sync-template.sh` (lines 27-60) — Why: auto-discovers new `template/.claude/**` files and re-chmods scripts — `claim-issue.sh` needs no sync-script edit
- `.agents/learnings/level-4.md` (lines 72-78 constraints; 91-97 deferred observations) — Why: worktree naming = plan slug, name-reuse resumes, and the three observations Level 5's walkthrough must capture
- `.agents/plans/level-4-worktree-isolation.md` — Why: the structural template for this plan's task/VALIDATE style

### New Files to Create

- `template/.claude/scripts/claim-issue.sh` — claim/release plumbing (label create+add+verify / remove+gc)
- `.agents/learnings/level-5.md` — learning doc (HARD GATE, root-only, never in template/)
- `.agents/learnings/level-5-diagram.mmd` — companion mermaid diagram

### Relevant Documentation YOU SHOULD READ THESE BEFORE IMPLEMENTING!

- [gh label create](https://cli.github.com/manual/gh_label_create) — `--force` = idempotent create-or-update. Why: labels MUST exist before `--add-label`; `--force` makes the create safe to run unconditionally
- [gh issue edit](https://cli.github.com/manual/gh_issue_edit) — `--add-label`/`--remove-label`, comma-separated. Why: the claim/release mutation; verified: adding a **nonexistent** label fails with "could not add label: not found" (it is NOT auto-created)
- [gh issue list](https://cli.github.com/manual/gh_issue_list) — `--label` filter (multiple = AND), `--json labels`. Why: release-time garbage-collection check ("any open issue still carrying this label?")
- [gh project item-list](https://cli.github.com/manual/gh_project_item-list) — JSON includes per-item `labels` (plain name strings) and `status`. Why: confirms claims flow through the existing board snapshot; **default `--limit` is 30** — the bug fix
- [GitHub rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) — secondary limit: ≤80 content-writes/min. Why: claim writes are 2-3 calls per issue pickup — far below limits; never loop claims across many issues without a sleep

### Patterns to Follow

**Script header + not-runnable note** (from `move-issue.sh` / `board-state.sh:7-8`):

```bash
#!/usr/bin/env bash
# <one-line purpose>
#
# NOTE: the template copy contains unfilled placeholder tokens and is not
# runnable; only the synced project copy is.
set -euo pipefail
```

**Placeholder usage** (everywhere): `--repo {{REPO_OWNER}}/{{REPO_NAME}}`; no new `workflow.env` entries needed — labels are not board fields.

**The In-Progress step every executor shares** (`execute.md:16-18`, identical in the other four) — the claim line lands immediately after the second line:

```
- Read the issue body: `gh issue view <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}}`
- Move the board item to "In Progress": `./.claude/scripts/move-issue.sh <NUMBER> "In Progress"`
```

**Board-discipline guard** (kept verbatim in every executor): `**Never close issues or move them to Done here — only `/commit` closes issues.**`

**VALIDATE style** (from level-4 plan): structural greps with expected counts, e.g. `` `grep -c 'claim-issue.sh' template/.claude/commands/execute.md` → 1 ``.

---

## INTEGRATION CONTRACTS

Single-component feature — no cross-component contracts. (Everything is markdown + bash inside one repo; the "contract" between sessions is the documented claim convention itself, specified in the tasks below and in workflow.md §10.)

---

## OBSERVABLE TRUTHS

- After an executor starts issue #N, the issue carries exactly one `worktree:<name>` label, visible in `gh issue view N --json labels` and in `board-state.sh` output
- A second session claiming the same issue gets a non-zero exit and a message naming the existing claimant; the issue still carries exactly one `worktree:*` label
- `/continue` in a second terminal lists the claimed issue with its owner and does NOT select it as next work
- A claimed issue whose worktree is absent from `git worktree list` (and whose claim isn't `main`) is flagged as a stale claim, with the user asked before clearing
- After `/commit` closes issue #N, the issue has no `worktree:*` labels; a `worktree:<name>` label carried by no open issue no longer exists in the repo's label list
- `board-state.sh` returns all board items (item-list called with an explicit `--limit`), not a silently truncated 30
- `./scripts/sync-template.sh` exits 0 with "OK: template synced, all placeholders resolved."; `./.claude/hooks/validate-local.sh` exits 0

## REQUIRED ARTIFACTS

- [ ] `template/.claude/scripts/claim-issue.sh` — claim/release plumbing (+ synced, executable root copy)
- [ ] Updated `template/.claude/scripts/board-state.sh` — `--limit 200` on `gh project item-list`
- [ ] Updated `template/.claude/commands/execute-isolated.md` — claim in Step 3, release in Step 7, Notes rewritten
- [ ] Updated `template/.claude/commands/execute.md`, `execute-team.md`, `hotfix.md`, `bug.md` — claim line in Step 0
- [ ] Updated `template/.claude/commands/commit.md` — release on close
- [ ] Updated `template/.claude/commands/continue.md` — worktree list gathered, claim column, claim-aware work order, stale-claim rule
- [ ] Updated `template/.claude/commands/status.md` — worktree list gathered, claims surfaced
- [ ] Updated `template/.claude/workflow.md` — §4 taxonomy row, §7 entries, new §10 Coordination Layer (old §10-12 → §11-13), plumbing enumeration
- [ ] Updated `template/.claude/skills/workflow/SKILL.md` — scripts checklist line + coordination guardrail
- [ ] `.agents/learnings/level-5.md` + `.agents/learnings/level-5-diagram.mmd` — HARD GATE

## KEY LINKS

- PRD: `.claude/PRD.md` §7 Level 5, §12 Phase 5 (validation: "2–3 terminal live test on real issues")
- Roadmap: `AGENTIC-EVOLUTION.md` lines 151-166 (Level 5 spec)
- GitHub issue: Phase 5 epic (created alongside this plan)
- Inherited obligation: `.agents/learnings/level-4.md:91-97` — three deferred observations (EnterWorktree branch-name format, `$CLAUDE_PROJECT_DIR` in-worktree, hooks firing in-worktree) to be recorded on the first traced `/execute-isolated` run — which should be THIS plan's execution

---

## IMPLEMENTATION PLAN

### Phase 1: Foundation (plumbing)

**Tasks:** `claim-issue.sh` (the deterministic claim/release mechanics), `board-state.sh` limit fix.

### Phase 2: Core Implementation (executor + commit integration)

**Tasks:** claim calls in all five executors' Step 0/3; release in `/commit` and `/execute-isolated` Step 7.

### Phase 3: Integration (awareness + documentation ripple)

**Tasks:** `/continue` + `/status` claim awareness; workflow.md §4/§7/new §10; SKILL.md; sync.

### Phase 4: Testing & Validation

**Tasks:** validation battery; learning doc + multi-terminal walkthrough (HARD GATE) which doubles as the PRD Phase 5 live test and captures Level 4's deferred observations.

---

## STEP-BY-STEP TASKS

IMPORTANT: Execute every task in order, top to bottom. Each task is atomic and independently testable.

### CREATE template/.claude/scripts/claim-issue.sh

- **IMPLEMENT**: Claim/release plumbing, ~60 lines. Interface:
  ```
  ./.claude/scripts/claim-issue.sh <issue-number> claim [<name>]
  ./.claude/scripts/claim-issue.sh <issue-number> release
  ```
  - `<name>` defaults by auto-detection: if `pwd` contains `/.claude/worktrees/<n>/` (or equals `.../.claude/worktrees/<n>`), name = `<n>`; otherwise `main`.
  - **claim**: (1) `gh label create "worktree:$NAME" --repo {{REPO_OWNER}}/{{REPO_NAME}} --color "5319e7" --description "Session ownership claim" --force` (idempotent — labels must exist before add, verified gh behavior); (2) `gh issue edit "$NUM" --repo {{REPO_OWNER}}/{{REPO_NAME}} --add-label "worktree:$NAME"`; (3) re-read: `gh issue view "$NUM" --repo {{REPO_OWNER}}/{{REPO_NAME}} --json labels --jq '[.labels[].name | select(startswith("worktree:"))]'`; if the array has >1 entry, remove own label (`--remove-label "worktree:$NAME"`) and exit 3 printing `CLAIM COLLISION: issue #$NUM already claimed by <other-label> — pick different work.` (GitHub has no compare-and-swap; this check-after-write is the race guard). On success print `Claimed #$NUM for worktree:$NAME`.
  - **release**: read the issue's `worktree:*` labels; remove each from the issue; for each removed label, if `gh issue list --repo {{REPO_OWNER}}/{{REPO_NAME}} --label "$L" --state open --json number --jq 'length'` is `0`, `gh label delete "$L" --repo {{REPO_OWNER}}/{{REPO_NAME}} --yes` (garbage-collect the label object). Releasing an unclaimed issue is a no-op, exit 0.
  - Arg validation + usage message on bad input (mirror `move-issue.sh`); `set -euo pipefail`; not-runnable-template header note.
- **PATTERN**: `template/.claude/scripts/move-issue.sh` (header, validation, placeholders); `create-issue.sh:52-54` (label syntax)
- **IMPORTS**: none — bash + `gh` only; do not add `workflow.env` entries (labels aren't board fields)
- **GOTCHA**: `--add-label` with a nonexistent label FAILS — the `--force` create must come first. `gh label delete` requires `--yes` non-interactively. Don't use `--search` on issue list (30/min search bucket); plain `--label` filter is fine.
- **VALIDATE**: `bash -n template/.claude/scripts/claim-issue.sh && echo syntax-ok` → syntax-ok; `grep -c '{{REPO_OWNER}}/{{REPO_NAME}}' template/.claude/scripts/claim-issue.sh` → ≥4; `grep -c 'label create' template/.claude/scripts/claim-issue.sh` → 1; `grep -c '\-\-force' template/.claude/scripts/claim-issue.sh` → ≥1; `grep -ci 'not.*runnable\|not runnable' template/.claude/scripts/claim-issue.sh` → ≥1
- **VERIFY**: claim path orders create→add→re-read→collision-backoff; release removes all `worktree:*` labels and GCs orphaned label objects; auto-detect falls back to `main`
- **DONE**: script exists, passes `bash -n`, mirrors move-issue.sh anatomy

### UPDATE template/.claude/scripts/board-state.sh

- **IMPLEMENT**: line 13: add `--limit 200` to the `gh project item-list` call (default 30 silently truncates; this repo's board is already at 28 items — coordination needs the full board)
- **PATTERN**: line 11 already passes an explicit `--limit 50` to `gh issue list`
- **GOTCHA**: change ONLY the limit — `/continue` and `/status` parse this JSON envelope
- **VALIDATE**: `grep -c 'item-list {{PROJECT_NUMBER}} --owner @me --format json --limit 200' template/.claude/scripts/board-state.sh` → 1; `bash -n template/.claude/scripts/board-state.sh && echo ok` → ok
- **VERIFY**: only line 13 changed
- **DONE**: item-list can no longer silently truncate

### UPDATE template/.claude/commands/execute-isolated.md

- **IMPLEMENT**: three edits:
  1. Step 3 (after the `move-issue.sh` line, line 49): add `- Claim the issue for this run's worktree: \`./.claude/scripts/claim-issue.sh <NUMBER> claim <slug>\` (the same plan-filename slug Step 4 uses for \`EnterWorktree\`). On CLAIM COLLISION (exit 3), STOP and tell the user which worktree owns the issue.` Note that re-entering a resumed worktree re-claims idempotently (adding an already-present label is a no-op).
  2. Step 7 (after the merge/cleanup block, line 110): add step 4: `Release the claim: ./.claude/scripts/claim-issue.sh <NUMBER> release` (if `/commit` closed the issue it already released — release is then a no-op).
  3. Notes (lines 120-122): replace "Coordination conventions (worktree ownership labels) arrive in Level 5." with a sentence stating the convention is live: claims are `worktree:<name>` labels managed by `claim-issue.sh`; `/continue` respects them (workflow.md §10).
- **PATTERN**: existing Step 3 bullet style; keep the "Never close issues" guard verbatim
- **GOTCHA**: claim happens in Step 3 BEFORE entering the worktree — so the name comes from the plan slug, not auto-detection. Rollback section: an abandoned run should also release (add one line there: after `ExitWorktree (remove)`, run `claim-issue.sh <NUMBER> release`).
- **VALIDATE**: `grep -c 'claim-issue.sh' template/.claude/commands/execute-isolated.md` → ≥3; `grep -c 'arrive in Level 5' template/.claude/commands/execute-isolated.md` → 0; `grep -c 'move-issue.sh' template/.claude/commands/execute-isolated.md` → 1; `grep -ci 'never close' template/.claude/commands/execute-isolated.md` → ≥1
- **VERIFY**: claim in Step 3 with explicit slug; release in Step 7 AND in Rollback; Notes updated
- **DONE**: /execute-isolated claims on pickup, releases on merge or abandon

### UPDATE the four other executors (execute.md, execute-team.md, hotfix.md, bug.md)

- **IMPLEMENT**: in each file's Step 0, immediately after the `move-issue.sh <NUMBER> "In Progress"` line, add: `- Claim the issue for this session: \`./.claude/scripts/claim-issue.sh <NUMBER> claim\` (auto-detects the worktree; \`main\` in the main checkout). On CLAIM COLLISION (exit 3), stop and ask the user.` Exact insertion points: `execute.md:18`, `execute-team.md:37`, `hotfix.md:23`, `bug.md:17` (verify line numbers by reading each file first).
- **PATTERN**: the shared Step 0 bullet anatomy (see Patterns to Follow)
- **GOTCHA**: `/chore` deliberately has NO issue linkage — do not touch `chore.md`. Do not alter each file's "Never close issues" guard or hotfix's "Status only, never Phase" discipline.
- **VALIDATE**: `for f in execute execute-team hotfix bug; do echo "$f: $(grep -c 'claim-issue.sh' template/.claude/commands/$f.md)"; done` → each 1; `grep -c 'claim-issue.sh' template/.claude/commands/chore.md` → 0 (file has no match — grep exits 1, count 0)
- **VERIFY**: one claim line per executor, placed after the move-issue line, none in chore.md
- **DONE**: every issue-linked executor claims at pickup

### UPDATE template/.claude/commands/commit.md

- **IMPLEMENT**: in Post-Commit step 2 (lines 69-70 area), after the "After every close, set the board Status yourself" bullet, add: `- **After every close, release the ownership claim:** \`./.claude/scripts/claim-issue.sh <NUMBER> release\` — removes any \`worktree:*\` label (no-op if unclaimed). Applies to feature issues and task sub-issues alike.`
- **PATTERN**: mirrors the adjacent move-issue.sh-Done bullet's phrasing and placement
- **GOTCHA**: release is close-scoped — progress-comment-only issues (not closed) keep their claims
- **VALIDATE**: `grep -c 'claim-issue.sh' template/.claude/commands/commit.md` → 1; `grep -c 'release' template/.claude/commands/commit.md` → ≥1
- **VERIFY**: release bullet sits inside the close flow, not the comment-only flow
- **DONE**: closing an issue always clears its claim

### UPDATE template/.claude/commands/continue.md

- **IMPLEMENT**: three edits:
  1. Step 1 git-state line (line 11): extend to `!\`git status --porcelain; git log --oneline -10; git branch --show-current; git worktree list\`` — local worktree liveness at zero API cost.
  2. Step 2 report table (line 17): add a `Claim` column (value: the `worktree:<name>` label's name part, or `—`). Add to the summary bullets: `- Issues **claimed by another session** (worktree:* label) and whether each claim looks **stale** (its worktree missing from \`git worktree list\` and not \`main\`)`.
  3. Step 3 work-order rules (lines 32-38): append two rules: `6. Skip issues claimed by another session — a worktree:<name> label counts as claimed unless <name> matches this session's worktree (or 'main' when running in the main checkout).` and `7. Stale claims (claimed worktree absent from git worktree list, claim not 'main') are surfaced, never silently taken: ask the user before clearing one with ./.claude/scripts/claim-issue.sh <NUMBER> release.`
- **PATTERN**: existing numbered-rule style in Step 3; existing table header style in Step 2
- **GOTCHA**: `git worktree list` in the main checkout also prints the main tree itself — the claim-liveness check is "does a worktree line ending in the claimed name exist". Claims data needs NO new API call — labels are already in `board-state.sh` output.
- **VALIDATE**: `grep -c 'git worktree list' template/.claude/commands/continue.md` → ≥2; `grep -c 'worktree:' template/.claude/commands/continue.md` → ≥2; `grep -c 'claim-issue.sh' template/.claude/commands/continue.md` → 1; `grep -c '^[0-9]\.' template/.claude/commands/continue.md` → 7
- **VERIFY**: rules 1-5 unchanged verbatim; skip rule + stale rule are additive
- **DONE**: /continue reads claims, skips others' work, surfaces stale claims

### UPDATE template/.claude/commands/status.md

- **IMPLEMENT**: (1) extend the git-state gather line with `git worktree list` (mirror continue.md); (2) in the report structure, add a claims element: list In-Progress issues with their claim owner (`worktree:<name>` or unclaimed) and flag stale claims — same stale definition as continue.md.
- **PATTERN**: continue.md's edits (this task mirrors them); status.md's existing report-section style
- **GOTCHA**: status is read-only — it reports stale claims but never clears them
- **VALIDATE**: `grep -c 'git worktree list' template/.claude/commands/status.md` → ≥1; `grep -c 'worktree:' template/.claude/commands/status.md` → ≥1; `grep -c 'claim-issue.sh' template/.claude/commands/status.md` → 0
- **VERIFY**: report-only; no mutation commands added
- **DONE**: /status shows who owns what

### UPDATE template/.claude/workflow.md

- **IMPLEMENT**: four edits:
  1. §4 label taxonomy table (after the Source row, ~line 110): add row `| **Worktree** | \`worktree:<name>\` (dynamic — created/removed by \`claim-issue.sh\`, never pre-created) | Session ownership claim (see §10) |`
  2. §7 entries: `/execute`, `/execute-team`, `/execute-isolated`, `/hotfix`, `/bug` — add claim to their board-lifecycle lines; `/commit` — add "releases worktree claims on close"; `/continue`, `/status` — add claim awareness to their Reads/Purpose lines.
  3. New section `## 10. Coordination Layer (Cross-Session)` inserted before the current `## 10. Key Decisions and Rationale` (line 402); renumber old §10→11, §11→12, §12→13. Content (~40 lines): the blackboard model (board + labels = shared state, `gh` hits the remote so claims are visible from every worktree); the claim lifecycle (claim at pickup → visible to all sessions → released on close/merge/abandon); the collision rule (no CAS on GitHub — claim-issue.sh re-reads after writing, backs off on collision, earliest claimant wins); the stale rule (worktree absent locally + not `main` = stale, user decides); scope (execution sessions claim; planning sessions don't — plans are read-mostly and live in the main tree); claim identity = worktree slug, `main` for the main checkout, at most one main-tree execution session at a time.
  4. Renumbered §13 "Changing This Workflow": plumbing enumeration (old line 455) gains `claim-issue`. Then check internal cross-references: `grep -n 'section 1[0-2]\|§1[0-2]' template/.claude/workflow.md` and fix any that point at the renumbered sections (the "(section 8)" ref at old line 382 is unaffected).
- **PATTERN**: §8 Hook Layer / §9 Subagent Layer — each level's layer gets a dedicated numbered section
- **GOTCHA**: renumbering three sections — sweep for stale cross-refs inside workflow.md AND in SKILL.md/commands (`grep -rn 'workflow.md.*§1[0-2]\|section 1[0-2]' template/.claude/`)
- **VALIDATE**: `grep -c '^## ' template/.claude/workflow.md` → 13; `grep -c 'Coordination Layer' template/.claude/workflow.md` → ≥1; `grep -c 'worktree:<name>' template/.claude/workflow.md` → ≥2; `grep -c '^### /' template/.claude/workflow.md` → 13; `grep -c 'claim-issue' template/.claude/workflow.md` → ≥3
- **VERIFY**: §4 row present; all 8 touched command entries mention claims; new §10 exists; §11-13 renumbered with no dangling cross-refs
- **DONE**: workflow.md §10 is the authoritative claim-convention spec

### UPDATE template/.claude/skills/workflow/SKILL.md

- **IMPLEMENT**: (1) impact-checklist scripts line (`board plumbing: board-state, move-issue, create-issue`) gains `claim-issue`; (2) Guardrails: add `- **Never change the claim convention without updating workflow.md §10 Coordination Layer** in the same change`.
- **PATTERN**: existing guardrail bullet style (lines 155-163)
- **GOTCHA**: also grep `template/.claude/commands/init-project.md` and `template/.claude/CLAUDE-template.md` for plumbing-script enumerations (`grep -n 'move-issue\|board-state' ...`) — if either enumerates scripts by name, add claim-issue there too; if not, no edit (do not invent one).
- **VALIDATE**: `grep -c 'claim-issue' template/.claude/skills/workflow/SKILL.md` → ≥1; `grep -c 'Coordination Layer' template/.claude/skills/workflow/SKILL.md` → 1
- **VERIFY**: checklist + guardrail only; no other skill-flow changes
- **DONE**: the meta-skill enforces the new lockstep piece

### RUN sync + validation battery

- **IMPLEMENT**: `./scripts/sync-template.sh` then confirm the synced script is executable and the battery is green. Commit is NOT part of this plan's tasks (`/commit` is its own step, run by the user after review).
- **VALIDATE**: `./scripts/sync-template.sh` → "OK: template synced, all placeholders resolved."; `test -x .claude/scripts/claim-issue.sh && echo exec-ok` → exec-ok; `grep -rn '{{' .claude/scripts/claim-issue.sh | wc -l` → 0; `./.claude/hooks/validate-local.sh && echo battery-green` → battery-green
- **VERIFY**: root copies match template; placeholders resolved with this repo's values
- **DONE**: live installation runs the new convention

### CREATE .agents/learnings/level-5.md + level-5-diagram.mmd (HARD GATE)

- **IMPLEMENT**: mirror level-4.md's section skeleton exactly (`# Level 5: … — What Changed and Why` / Status+Commits+Diagram header / `## The gap this closes` / `## What changed, file by file` / `## How information flows now` (before/after) / `## See it yourself (the walkthrough script)` / `## What to watch out for` / `## Interesting findings from the build` / `## Walkthrough log`). The walkthrough script MUST include, numbered:
  1. Static grep: the claim line exists in each executor (the VALIDATE greps above).
  2. **The main event (PRD Phase 5 validation):** 2-3 terminals on real issues — terminal 1 `/execute-isolated` a small real plan (claims `worktree:<slug>`), terminal 2 runs `/continue` and must show the claim and refuse to select that issue, terminal 3 (optional) `/hotfix` in a second worktree on a different issue.
  3. Deliberately-triggered collision: from the main tree, `./.claude/scripts/claim-issue.sh <claimed-N> claim` → exit 3, message names the owning worktree, issue still has exactly one claim label.
  4. Stale-claim demo: remove a claimed worktree, run `/continue`, watch the stale flag + ask-before-clear.
  5. Release proof: `/commit` closes the issue → `gh issue view N --json labels` shows no `worktree:*`; label object GC'd when orphaned.
  6. **Settle Level 4's deferred observations** (level-4.md:91-97): record EnterWorktree branch-name format, `$CLAUDE_PROJECT_DIR` resolution in-worktree, hooks firing in-worktree — this plan's own execution via `/execute-isolated` is the "first traced run".
  Diagram: multi-session blackboard flow (sessions ↔ board/labels ↔ claim lifecycle).
- **PATTERN**: `.agents/learnings/level-4.md` structure; deferred-with-conditions honesty convention for anything not captured live
- **GOTCHA**: root-only — never under `template/`; sign-off is recorded as a comment on the Phase 5 epic and the gate blocks all Level 6 work
- **VALIDATE**: `test -f .agents/learnings/level-5.md && grep -c '^## ' .agents/learnings/level-5.md` → ≥6; `test -f .agents/learnings/level-5-diagram.mmd && echo ok` → ok
- **VERIFY**: walkthrough script includes the multi-terminal live test, the collision demo, and the Level-4 deferred-observations checklist
- **DONE**: doc + diagram exist; walkthrough performed; owner sign-off recorded on the epic (HARD GATE)

---

## TESTING STRATEGY

### Unit Tests

N/A — no test framework. Per-task structural greps (VALIDATE lines above) play this role, per this repo's convention.

### Integration Tests

Sync + battery (`sync-template.sh`, `validate-local.sh`) prove template/root consistency, placeholder resolution, and shell syntax. Live `gh` behavior (claim, collision, release, GC) is deliberately excluded from automated VALIDATE (no dry-run support in plumbing scripts, mutations hit the real board) and lands in the walkthrough instead — this repo's established pattern.

### Edge Cases

- Claim collision (two sessions, same issue) → second claimant backs off, exit 3
- Re-claim by the same worktree (resumed session / resumed worktree) → idempotent no-op success
- Release of an unclaimed issue → no-op, exit 0
- Stale claim (worktree deleted without release) → flagged by `/continue`, cleared only with user consent
- Label GC when a claim label is shared by an epic + its task sub-issues → label object survives until the LAST open issue releases it
- Main-checkout execution (`worktree:main`) → claims work without any worktree

---

## VALIDATION COMMANDS

Execute every command to ensure zero regressions and 100% feature correctness.

### Level 1: Syntax & Style

```bash
for f in scripts/*.sh template/.claude/hooks/*.sh template/.claude/scripts/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
```

### Level 2: Unit Tests

The per-task structural greps (VALIDATE lines above), top to bottom.

### Level 3: Integration Tests

```bash
./scripts/sync-template.sh          # → "OK: template synced, all placeholders resolved."
./.claude/hooks/validate-local.sh && echo battery-green
test -x .claude/scripts/claim-issue.sh && echo exec-ok
```

### Level 4: Manual Validation

The walkthrough script in `.agents/learnings/level-5.md` (multi-terminal live test on real issues — the PRD Phase 5 validation). Smoke-test claim/release once against a real issue before the walkthrough: `./.claude/scripts/claim-issue.sh <epic-N> claim && gh issue view <epic-N> --json labels && ./.claude/scripts/claim-issue.sh <epic-N> release`.

---

## ACCEPTANCE CRITERIA

- [ ] `claim-issue.sh` claims (create→add→verify, collision backoff) and releases (remove + label GC) correctly
- [ ] All five issue-linked executors claim at pickup; `/chore` untouched
- [ ] `/commit` releases claims on every close
- [ ] `/continue` surfaces claims, skips other sessions' issues, flags stale claims and asks before clearing
- [ ] `/status` reports claim ownership read-only
- [ ] `board-state.sh` item-list has an explicit `--limit`
- [ ] workflow.md documents the convention (§4 row, §7 entries, new §10 Coordination Layer); SKILL.md checklist + guardrail updated
- [ ] Sync green, battery green, zero unresolved placeholders
- [ ] Multi-terminal walkthrough performed on real issues (PRD Phase 5 validation) incl. collision + stale demos
- [ ] Level 4's three deferred observations recorded in level-5.md (or explicitly re-deferred with conditions)
- [ ] `.agents/learnings/level-5.md` + diagram exist; owner sign-off on the Phase 5 epic (HARD GATE — blocks Level 6)

---

## COMPLETION CHECKLIST

- [ ] All tasks completed in order
- [ ] Each task validation passed immediately
- [ ] All validation commands executed successfully
- [ ] Sync + battery pass
- [ ] Manual walkthrough confirms the convention works across terminals
- [ ] Acceptance criteria all met
- [ ] Owner sign-off recorded (HARD GATE)

---

## NOTES

**Executor recommendation: `/execute-isolated` (wrapping the default single-agent `/execute` path).** Single-component plan → single-agent executor; running it via the worktree envelope dogfoods Level 4 AND satisfies level-4.md's "first traced run" obligation, capturing the three deferred observations during this plan's own execution. Fallback: plain `/execute` in the main tree if worktree tools are unavailable.

**Design decision — label, not comment, as the claim marker.** `board-state.sh` already emits labels for open issues (line 11) and board items (item-list JSON includes plain-string label names, verified live), so `/continue`/`/status` see claims with zero extra API calls; labels are visible in the GitHub UI at a glance. Comments were the runner-up (they carry timestamps and give an earliest-wins tiebreak) but cost one `gh issue view` per issue to read. The collision-verify step in `claim-issue.sh` compensates for labels' lack of ordering: after writing, re-read; if two `worktree:*` labels coexist, the later writer backs off. For a solo dev routing 2-3 terminals by hand, race probability is minutes-wide, and the verify step covers it.

**⚠️ HIGH-STAKES flag (CLAUDE.md Decision Protocol):** adding the `worktree:` category is a **label-taxonomy change** — explicitly a stop-and-ask item. Plan approval (HUMAN GATE 1) is that ask: approving this plan approves the taxonomy addition. Mitigations: the category is dynamic and self-cleaning (labels are created on claim, GC'd on release — the taxonomy row documents a *pattern*, not a fixed label set); no existing label changes; no migration for existing template users (absent labels simply mean "unclaimed").

**Deviation from the roadmap's "convention only, no code" estimate:** one ~60-line script is included because the claim mechanics contain two fumble-prone deterministic steps (label-must-exist-before-add; post-write collision verify) — exactly the "how to type, not how to think" work the Extraction Rule (PRD §6) assigns to scripts. The convention itself (who claims, when, what's stale) stays prose in workflow.md §10.

**Command count stays 16** — no new command, so init-project/CLAUDE.md command counts are untouched (only script enumerations change, checked in the SKILL.md task).

**Rate-limit note:** claim = ≤3 API writes per issue pickup; reads ride the existing board-state call. Far below GitHub's 80 writes/min secondary limit; no polling loops introduced.
