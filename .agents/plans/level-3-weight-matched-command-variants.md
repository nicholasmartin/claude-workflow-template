# Feature: Level 3 — Weight-Matched Command Variants

The following plan should be complete, but validate documentation and codebase patterns and task sanity before you start implementing.

Pay special attention to the sync model: **every product edit lands in `template/`, never in root `.claude/`**, and `./scripts/sync-template.sh` must run before the turn ends (the Stop-hook battery enforces this).

## Feature Description

Level 3 of AGENTIC-EVOLUTION.md / Phase 3 of the PRD: the full executor spectrum, light to heavy, so workflow weight matches ticket weight. Today every ticket gets `/execute`'s full ceremony (plan file, per-task verifier subagents, verdict gates). Level 3 adds:

- **Light executors:** `/hotfix` (speed-first, no PRD/plan ceremony), `/chore` (no issue linkage, `chore:` commit), `/bug` (failing-test-first, issue body as context)
- **Minimal planners:** `/plan-hotfix` (what's broken / what's the fix / ship it), `/plan-bug` (repro + logs → minimal fix plan)
- **Heavy executor:** `/execute-team` — ported from `~/projects/nexus/.claude/skills/execute-team/` (itself adapted from coleam00's MIT-licensed `build-with-agent-team`). A lead agent distributes Integration Contracts from the plan to teammate agents (experimental agent-teams feature) with exclusive file ownership, runs contract diffs + cross-review + end-to-end validation, hands off to `/commit`.
- `/plan-feature` gains an **executor recommendation** (single-domain → `/execute`; multi-component per Integration Contracts → `/execute-team`).

The existing 9 commands keep their names and calling conventions (muscle-memory preservation). Level 1 hooks still guard every variant — what the light variants shed is *ceremony* (plan files, issue creation, verifier subagents), never the deterministic validation layer.

## User Story

As a solo developer using the workflow template
I want executor and planner variants matched to ticket weight
So that a typo fix costs typo-fix ceremony while multi-component features get contract-driven team execution.

## Problem Statement

`/execute` is one-size-fits-all. A typo fix pays for plan-file ceremony, issue choreography, and verifier subagents it doesn't need (PRD success criterion: a chore should ship with ≤25% of a feature's tool calls). At the other end, a multi-component feature gets only one sequential agent when parallel teammates building against agreed contracts would be faster and catch integration mismatches earlier. Level 2 already landed the Integration Contracts plan section specifically so a team executor could consume it — that consumer doesn't exist here yet.

## Solution Statement

Add six new command files to `template/.claude/commands/` (five light, one heavy), each mirroring `/execute`'s proven board-lifecycle patterns (`move-issue.sh`, "only /commit closes issues", deviation rules) but sized to their ticket weight. Port the nexus `execute-team` skill as a single command file with nexus refs genericized to sync placeholders. Update `/plan-feature`, `workflow.md`, the workflow skill, `init-project.md`, and `CLAUDE.md` in lockstep (workflow-skill guardrail), then sync.

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: Medium-High (6 new files + 5 ripple updates; no new runtime machinery — all markdown + existing plumbing)
**Primary Systems Affected**: `template/.claude/commands/`, `template/.claude/workflow.md`, `template/.claude/skills/workflow/SKILL.md`, root `CLAUDE.md`
**Dependencies**: Level 2 sign-off (hard gate — epic #10); Claude Code experimental agent-teams feature for `/execute-team` (env flag, with documented fallback)

---

## CONTEXT REFERENCES

### Relevant Codebase Files IMPORTANT: YOU MUST READ THESE FILES BEFORE IMPLEMENTING!

- `template/.claude/commands/execute.md` (lines 1-30, 159-186) — Why: frontmatter style, Step 0 issue linking (`gh issue view` + `move-issue.sh` at lines 17-18), pre-flight checks, Deviation Rules (line 159) — the patterns every light variant halves
- `template/.claude/commands/commit.md` (lines 22-26, 61-75) — Why: tag selection ("feat", "fix", "docs") and issue-closing logic the variants hand off to; `/chore`'s no-issue path must no-op here naturally (it does — step 3 "If no open issues are affected, skip")
- `template/.claude/commands/plan-feature.md` (lines 116-122 Design Decisions, 492-528 Report) — Why: where the executor recommendation slots in
- `/home/nickmartin/projects/nexus/.claude/skills/execute-team/SKILL.md` (all 212 lines) — Why: the port source; nexus-specific refs at lines 38, 174, 176 (`--repo nicholasmartin/nexus`), board-move prose at lines 39-40, single-view note at lines 104-108
- `template/.claude/workflow.md` (§7 lines 234-272, §8 lines 275-311, §9 lines 314-350) — Why: command catalog entries to extend; §9 line 348 says "a team-based executor arrives in a later phase" — that phase is now
- `template/.claude/skills/workflow/SKILL.md` (lines 26-35 roster, 58-79 impact checklist) — Why: both enumerations gain the 6 new files
- `template/.claude/commands/init-project.md` (line 145 command-verification loop, line 548 "9 slash commands configured") — Why: both enumerate commands; copied verbatim by sync
- `CLAUDE.md` (line 63 "9 slash commands") — Why: count update; root-only file, edited directly, never synced
- `scripts/sync-template.sh` (lines 38-56 sed token list, 71-86 placeholder guard) — Why: defines which `{{TOKEN}}`s are legal in new command files
- `.agents/plans/level-2-parallel-subagents.md` — Why: house style for tasks and validation; its NOTES record the nested-fence and placeholder-scan lessons

### New Files to Create

- `template/.claude/commands/chore.md` — lightest executor: no issue, no plan, single validation pass, `chore:` commit
- `template/.claude/commands/hotfix.md` — speed-first executor: existing issue optional, Status-only board move, `fix:` commit
- `template/.claude/commands/bug.md` — failing-test-first executor: issue body as context, repro before fix
- `template/.claude/commands/plan-hotfix.md` — minimal planner: broken / fix / validate, tiny plan file
- `template/.claude/commands/plan-bug.md` — minimal bug planner: repro + logs → fix plan with test-first task
- `template/.claude/commands/execute-team.md` — ported heavy executor (lead + teammates via agent teams)

### Relevant Documentation YOU SHOULD READ THESE BEFORE IMPLEMENTING!

- [Agent teams](https://code.claude.com/docs/en/agent-teams) — enablement (`#enable-agent-teams`), limitations (`#limitations`), display modes (`#choose-a-display-mode`)
  - Why: `/execute-team`'s preflight, fallback text, and display guidance must match current reality: flag is still `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; `TeamCreate`/`TeamDelete` tools no longer exist (team forms on first teammate spawn); default display is in-process since v2.1.179 (do NOT require tmux); one team per session, no nested teams; teammates don't inherit the lead's conversation — spawn prompts must carry the full contract slice
- [Skills & commands (merged)](https://code.claude.com/docs/en/skills) — `#frontmatter-reference`, `#available-string-substitutions`
  - Why: commands and skills are now one system with identical frontmatter (`description`, `argument-hint`, `disable-model-invocation` all valid in `commands/*.md`); `$ARGUMENTS[N]` is 0-based — the nexus source already uses `$ARGUMENTS[0]`/`[1]` correctly, keep it
- [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) — Why: `hotfix:` is NOT a conventional type; `/hotfix` hands off with `fix:`; `chore:` is a recognized additional type
- [Fowler on test-first bug fixing](https://martinfowler.com/bliki/TestPyramid.html) — Why: the canonical "replicate the bug with a test... the test ensures the bug stays dead" citation for `/bug`
- [coleam00/context-engineering-intro `build-with-agent-team`](https://github.com/coleam00/context-engineering-intro/tree/main/use-cases/build-with-agent-team) — Why: upstream origin (MIT); attribution line in the port stays

### Patterns to Follow

**Frontmatter (7 of 9 existing commands):**

```yaml
---
description: Execute an implementation plan
argument-hint: [path-to-plan]
---
```

**Issue linking + Status-only board move (execute.md:17-18):**

```markdown
- Read the issue body: `gh issue view <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}}`
- Move the board item to "In Progress": `./.claude/scripts/move-issue.sh <NUMBER> "In Progress"`
```

`move-issue.sh` sets the **Status field only** — it never touches Phase. This is exactly how `/hotfix` satisfies "doesn't touch board Phase field": use the script, never pass `--phase` anywhere.

**Issue lifecycle rule (every executor, verbatim from execute.md / nexus SKILL.md):**

```markdown
**Never close issues or move them to Done here — only `/commit` closes issues.**
```

**Placeholder discipline:** new command files may contain ONLY the tokens in sync-template.sh's sed list (`{{PROJECT_NAME}}`, `{{REPO_OWNER}}`, `{{REPO_NAME}}`, `{{PROJECT_NUMBER}}`, field/option IDs). Any other `{{UPPER_CASE}}` string fails the sync guard and the Stop battery — the whitelist has exactly one file (init-project.md) and these commands are not on it. Write illustrative placeholders as `<angle-brackets>`, never `{{BRACES}}`.

**Structural invariants (all 9 existing commands):** exactly one `# ` H1, `## ` sections throughout, frontmatter `description:` for anything new. Do NOT assert a `## Report` section (not universal).

---

## INTEGRATION CONTRACTS

Single-component feature — no cross-component contracts. (Everything is markdown in one repo; the only "interface" is command → plumbing-script invocations, which reuse existing script contracts unchanged.)

---

## OBSERVABLE TRUTHS

- Running `/chore <small task>` performs the task with **zero** GitHub issue creation, zero plan files, zero subagent spawns, and hands off to `/commit` with an explicit `chore:` prefix instruction (PRD: ≤25% of a feature's tool calls)
- Running `/hotfix <issue>` moves the issue's board **Status** to "In Progress" via `move-issue.sh` and never sets the Phase field
- Running `/bug <issue>` produces a failing repro (test where a framework exists, recorded manual repro otherwise) **before** any fix is applied
- `/execute-team`'s Step 1 preflight checks `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`; when unset it stops with a clear message naming `/execute` as the fallback
- A `/plan-feature` run's final report contains a "Recommended executor" line derived from the plan's INTEGRATION CONTRACTS section
- `ls template/.claude/commands/*.md | wc -l` → 15, and after sync `ls .claude/commands/*.md | wc -l` → 15
- `./.claude/hooks/validate-local.sh` exits 0 (placeholders resolved, no drift, shell syntax clean)
- The 9 pre-existing command files are byte-identical to their pre-Level-3 versions except `plan-feature.md` and `init-project.md` (the only two with in-scope edits)

## REQUIRED ARTIFACTS

- [ ] `template/.claude/commands/chore.md` (~60 lines)
- [ ] `template/.claude/commands/hotfix.md` (~85 lines)
- [ ] `template/.claude/commands/bug.md` (~95 lines)
- [ ] `template/.claude/commands/plan-hotfix.md` (~55 lines)
- [ ] `template/.claude/commands/plan-bug.md` (~75 lines)
- [ ] `template/.claude/commands/execute-team.md` (~215 lines, ported)
- [ ] Updated `template/.claude/commands/plan-feature.md` — executor recommendation in Phase 4 + Report
- [ ] Updated `template/.claude/workflow.md` — §7 entries for all 6, §9 roster row + contracts-consumer sentence
- [ ] Updated `template/.claude/skills/workflow/SKILL.md` — roster + impact checklist gain 6 files
- [ ] Updated `template/.claude/commands/init-project.md` — command loop (line 145) + count (line 548)
- [ ] Updated `CLAUDE.md` — command count line 63 (root-only, direct edit)
- [ ] Regenerated root `.claude/` via `./scripts/sync-template.sh`

## KEY LINKS

- PRD: `.claude/PRD.md` §7 Level 3, §12 Phase 3, §14 (agent-teams risk row)
- Roadmap: `AGENTIC-EVOLUTION.md` lines 110-129 (Level 3 spec)
- GitHub epic: created by this plan's report step (Phase 3 epic)
- Port source: `/home/nickmartin/projects/nexus/.claude/skills/execute-team/SKILL.md`
- Agent teams docs: https://code.claude.com/docs/en/agent-teams

---

## IMPLEMENTATION PLAN

### Phase A: Light executors

`/chore`, `/hotfix`, `/bug` — each mirrors `/execute`'s board patterns at reduced weight. Build lightest-first so the weight ladder stays honest (each adds exactly one rung of ceremony).

### Phase B: Minimal planners

`/plan-hotfix`, `/plan-bug` — tiny plan files consumable by the light executors or `/execute`.

### Phase C: Heavy executor port

`/execute-team` from nexus: genericize repo refs, swap board-move prose for `move-issue.sh`, add env-flag preflight + fallback, keep contract machinery verbatim.

### Phase D: Integration & ripple

`/plan-feature` recommendation; workflow.md §7/§9; workflow skill enumerations; init-project.md; CLAUDE.md count; sync; battery.

---

## STEP-BY-STEP TASKS

IMPORTANT: Execute every task in order, top to bottom. Invoke the `template:workflow` skill before starting — this feature is a workflow-system change and the skill's lockstep checklist governs it. All edits under `template/`; never edit root `.claude/` copies.

### CREATE template/.claude/commands/chore.md

- **IMPLEMENT**: Frontmatter (`description: Ship a small maintenance task with minimum ceremony — no issue, no plan file`, `argument-hint: [task-description]`). H1 `# Chore: Minimum-Ceremony Maintenance`. Sections: **When to use** (typo fixes, dep bumps, doc touch-ups, rename/move — anything a reviewer would approve at a glance; escalate to `/bug` or `/plan-feature` if it grows); **Step 1: Do the task** (make the change directly; deviation rule: if the "chore" reveals a real bug or design question, STOP and recommend the right-weight command); **Step 2: Single validation pass** (run the narrowest relevant check — the Stop-hook battery still fires regardless; state that contract explicitly: "the per-turn battery is unskippable; this step only adds anything task-specific"); **Step 3: Hand off** ("run `/commit`; the commit tag MUST be `chore:` (or `docs:` for pure docs). No GitHub issue is created, linked, or closed — /commit's issue step naturally no-ops."). NO board calls, NO `gh issue` calls, NO subagents.
- **PATTERN**: execute.md:1-5 (frontmatter), commit.md:58 (chore/docs tag rule)
- **GOTCHA**: keep it genuinely tiny (~60 lines) — the PRD's ≤25%-tool-calls criterion is measured against this file's ceremony
- **VALIDATE**: `test -f template/.claude/commands/chore.md && grep -c 'chore:' template/.claude/commands/chore.md` → ≥2; `grep -c 'gh issue' template/.claude/commands/chore.md` → 0
- **VERIFY**: file has frontmatter description, one H1, no `{{` tokens outside the sed list (none at all expected)
- **DONE**: chore.md exists, no issue/board choreography anywhere in it

### CREATE template/.claude/commands/hotfix.md

- **IMPLEMENT**: Frontmatter (`description: Speed-first fix for an urgent breakage — single agent, no plan ceremony, board Status only`, `argument-hint: [issue-number-or-description]`). H1 `# Hotfix: Ship the Fix Fast`. Sections: **When to use** (prod-impacting breakage where speed beats ceremony; if root cause is unclear, use `/plan-hotfix` first or `/bug`); **Step 0: Link the issue (if one exists)** — MIRROR execute.md:17-18 verbatim (`gh issue view <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}}`, `./.claude/scripts/move-issue.sh <NUMBER> "In Progress"`) plus an explicit line: "Status only — a hotfix never sets the Phase field. If no issue exists, skip this step entirely; do not create one."; **Step 1: Diagnose fast** (read the failure, find the smallest correct fix; deviation rules trimmed to: fix inline OK, boundary validation OK, **architecture changes → STOP** — this is execute.md's rule 4 verbatim); **Step 2: Fix + prove it** (apply fix; demonstrate the broken behavior is gone — one targeted validation, not the full suite; battery still fires); **Step 3: Hand off** ("run `/commit` with a `fix:` tag — `hotfix` is not a Conventional Commits type. Leave the issue open; only /commit closes issues.").
- **PATTERN**: execute.md:17-18 (Step 0), execute.md:159-181 (deviation rules to trim), conventionalcommits.org (fix: not hotfix:)
- **GOTCHA**: `{{REPO_OWNER}}/{{REPO_NAME}}` are legal (in sync's sed list) and required for the `gh issue view` line
- **VALIDATE**: `grep -c 'move-issue.sh' template/.claude/commands/hotfix.md` → 1; `grep -c 'Phase' template/.claude/commands/hotfix.md` → ≥1 (the never-sets-Phase line); `grep -c 'fix:' template/.claude/commands/hotfix.md` → ≥1
- **VERIFY**: no `create-issue.sh` call, no `--phase` string anywhere in the file
- **DONE**: hotfix.md exists with Status-only board semantics and fix: handoff

### CREATE template/.claude/commands/bug.md

- **IMPLEMENT**: Frontmatter (`description: Fix a reported bug with a failing-test-first workflow — issue body as context`, `argument-hint: [issue-number]`). H1 `# Bug: Reproduce, Then Fix`. Sections: **Step 0: Pull the context** — `gh issue view <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}} --comments` (body + comments are the repro source), then `./.claude/scripts/move-issue.sh <NUMBER> "In Progress"`; **Step 1: Reproduce first (the contract of this command)** — "Before touching the fix: write a failing test that captures the bug (cite Fowler: the test ensures the bug stays dead). If the project has no test framework, reproduce manually and record the exact repro steps + observed-vs-expected in the issue as a comment. **Do not proceed to Step 2 until you have a red repro.**"; **Step 2: Fix** (smallest change that turns the repro green; execute.md deviation rules 1-3 apply, rule 4 verbatim: architecture changes → STOP); **Step 3: Prove the death** (failing test now passes; targeted validation; battery fires regardless); **Step 4: Close-out** (check off satisfied AC in the issue body, comment the repro + fix summary, leave issue OPEN, hand to `/commit` with `fix:` tag).
- **PATTERN**: execute.md:17-18 (linking), execute.md deviation rules, martinfowler.com/bliki/TestPyramid.html (test-first citation)
- **GOTCHA**: graceful degradation is mandatory — the template is language-agnostic, so "no test framework" is a first-class path, not a failure
- **VALIDATE**: `grep -cin 'failing' template/.claude/commands/bug.md` → ≥2; `grep -c 'move-issue.sh' template/.claude/commands/bug.md` → 1
- **VERIFY**: Step 1 (repro) appears before any fix instruction; no-framework path present
- **DONE**: bug.md exists with an unskippable red-repro gate

### CREATE template/.claude/commands/plan-hotfix.md

- **IMPLEMENT**: Frontmatter (`description: Minimal hotfix plan — what's broken, what's the fix, ship it`, `argument-hint: [issue-number-or-description]`). H1 `# Plan Hotfix: Broken → Fix → Ship`. Process: read the issue/description (+ `gh issue view` if a number was given), inspect only the directly implicated files (no scout fan-out — that's `/plan-feature` weight), then write `.agents/plans/hotfix-<kebab-slug>.md` containing exactly five sections: **What's broken** (symptom + evidence), **Root cause** (file:line), **The fix** (specific change), **Risk** (what could regress), **Validation** (1-3 exact commands). Target ≤40 lines of plan. End: "hand the plan to `/hotfix` (or `/execute` if it grew beyond hotfix weight — say so explicitly)."
- **PATTERN**: plan-feature.md Output Format (kebab-case filenames in `.agents/plans/`); the anti-pattern is plan-feature's own 500-line template — this planner is its deliberate opposite
- **GOTCHA**: if the mini-plan skeleton is shown as an embedded fenced markdown block containing its own fences, the outer fence must be 4 backticks (level-2 lesson). Prefer a plain bulleted section list — no nested fences at all.
- **VALIDATE**: `grep -c 'agents/plans/hotfix-' template/.claude/commands/plan-hotfix.md` → ≥1; `awk '/^````/{n++} END{print n+0}' template/.claude/commands/plan-hotfix.md` → 0 or 2 (no unbalanced 4-fences)
- **VERIFY**: no scout/subagent spawning anywhere in the file
- **DONE**: plan-hotfix.md exists, produces ≤40-line plans, zero subagents

### CREATE template/.claude/commands/plan-bug.md

- **IMPLEMENT**: Frontmatter (`description: Minimal bug-fix plan from repro and logs — failing-test-first task order`, `argument-hint: [issue-number]`). H1 `# Plan Bug: Repro → Root Cause → Fix Plan`. Process: pull issue body + comments (`gh issue view <NUMBER> --repo {{REPO_OWNER}}/{{REPO_NAME}} --comments`), gather evidence (logs/stack traces referenced in the issue, the implicated code paths — read directly; at most ONE `Explore` subagent if the codebase area is genuinely unfamiliar, and say why), then write `.agents/plans/bug-<issue-number>-<kebab-slug>.md` with sections: **Repro** (exact steps/inputs, observed vs expected), **Root cause hypothesis** (file:line + reasoning), **Fix plan** (ordered tasks where task 1 is ALWAYS "write the failing test / record the red repro"), **Observable truths** (2-3), **Validation commands** (exact). Recommend executor at the end: `/bug <NUMBER>` normally, `/execute` if multi-file. Keep the plan ≤80 lines.
- **PATTERN**: bug.md's red-repro gate (task 1 mirrors it); plan-feature.md Output Format
- **GOTCHA**: same nested-fence rule as plan-hotfix.md; same placeholder discipline
- **VALIDATE**: `grep -c 'agents/plans/bug-' template/.claude/commands/plan-bug.md` → ≥1; `grep -cin 'failing' template/.claude/commands/plan-bug.md` → ≥1
- **VERIFY**: fix-plan task order puts the failing test first
- **DONE**: plan-bug.md exists with test-first task ordering baked in

### CREATE template/.claude/commands/execute-team.md (the port)

- **IMPLEMENT**: Copy `/home/nickmartin/projects/nexus/.claude/skills/execute-team/SKILL.md` content as a single command file, then apply these deltas:
  1. Frontmatter: keep `description`, `argument-hint: [path-to-plan] [num-agents]`, `disable-model-invocation: true` (valid in commands — commands/skills share frontmatter now); drop `name:` if it conflicts with filename-derived naming (keep if harmless).
  2. Lines 38, 174, 176: `--repo nicholasmartin/nexus` → `--repo {{REPO_OWNER}}/{{REPO_NAME}}`.
  3. Lines 39-40 (board move prose) → the template's canonical call: `./.claude/scripts/move-issue.sh <NUMBER> "In Progress"` (mirror execute.md:18).
  4. NEW preflight (extend Step 1): check the feature flag before anything else — if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not set (settings.json `env` block or environment), STOP with: "Agent teams are not enabled. Either set CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in settings and restart, or run `/execute <plan>` — the single-agent executor handles the same plan." Also note the documented limitations that matter operationally: one team per session; no nested teams; teammates do not inherit this conversation (spawn prompts must carry the full contract slice — the Step 4 prompt template already does).
  5. Step 4 display note: update "single view (no tmux)" to reflect current default — in-process is the default display mode; split panes are optional (`teammateMode`), never required.
  6. Keep verbatim: Step 3 contract machinery + quality bar (it maps 1:1 onto plan-feature's INTEGRATION CONTRACTS section — checked during Level 2), Step 5 facilitation/contract diff/cross-review, Step 6 two-level validation, Step 7 close-out, Definition of Done, Pitfalls, attribution line to coleam00 (MIT).
  7. Do NOT port README.md or example-plan/ — the template's plan-feature template + `.agents/plans/EXAMPLE.md` are the canonical contract-rich examples here.
- **PATTERN**: nexus SKILL.md (source); execute.md:17-18 (board calls); workflow.md §9 quality bar (contracts language must stay aligned)
- **IMPORTS**: n/a (markdown)
- **GOTCHA**: `$ARGUMENTS[0]`/`$ARGUMENTS[1]` in the source are correct per current 0-based docs — do not "fix" them. The file will be placeholder-substituted by sync (it is not init-project.md) — that is exactly what the `{{REPO_OWNER}}` swaps rely on.
- **VALIDATE**: `grep -c 'nicholasmartin/nexus' template/.claude/commands/execute-team.md` → 0; `grep -c 'move-issue.sh' template/.claude/commands/execute-team.md` → 1; `grep -ci 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' template/.claude/commands/execute-team.md` → ≥2; `grep -c 'only .commit. closes\|only \`/commit\` closes' template/.claude/commands/execute-team.md` → ≥1
- **VERIFY**: fallback-to-/execute text present; contract quality bar intact (trailing slashes, explicit JSON, error bodies, storage semantics all still named)
- **DONE**: execute-team.md exists, fully genericized, flag-gated with documented fallback

### UPDATE template/.claude/commands/plan-feature.md — executor recommendation

- **IMPLEMENT**: (1) In Phase 4 "Design Decisions" (line ~116), add bullet: "Decide the executor: single-domain plan → `/execute`; multi-component plan with a populated INTEGRATION CONTRACTS section → `/execute-team`; record the choice and rationale in the plan's NOTES". (2) In the Report's item 3 "Provide:" list (lines ~522-528), add bullet: "Recommended executor (`/execute` or `/execute-team`) with one-line rationale". Touch nothing else — especially not the scout fan-out prose ("single message" is load-bearing) or the 4-backtick template fences.
- **PATTERN**: plan-feature.md:116-122, 492-528
- **GOTCHA**: this file's outer template fence is 4 backticks; your edits are outside the fence but re-verify the balance after editing
- **VALIDATE**: `grep -c 'Recommended executor' template/.claude/commands/plan-feature.md` → ≥1; `grep -c '^````' template/.claude/commands/plan-feature.md` → 2; `grep -c 'single message' template/.claude/commands/plan-feature.md` → ≥1 (fan-out intact)
- **VERIFY**: recommendation keys off the INTEGRATION CONTRACTS section, not vibes
- **DONE**: plan-feature reports an executor recommendation

### UPDATE template/.claude/workflow.md — §7 + §9

- **IMPLEMENT**: (1) §7: after the `/execute` entry (line ~251), add catalog entries for `/execute-team` (Reads: plan; Spawns: teammate agents via experimental agent-teams — lead coordinates, contracts from the plan's Integration Contracts section; Updates: In Progress via move-issue.sh, AC check-offs; Post: comments summary, only /commit closes), `/hotfix` (Reads: issue if given; Updates: Status only — never Phase; no plan file), `/bug` (Reads: issue body + comments; contract: failing repro before fix), `/chore` (no GitHub interaction — state it explicitly like /create-prd does), `/plan-hotfix` and `/plan-bug` (Reads: issue/logs; Creates: minimal plan file; no board writes unless issue exists). Follow the existing entry format exactly. (2) §9 Roster table: add row — `/execute-team` | Teammate agents (2-5) | agent-teams (experimental) | Parallel component builds against contract slices, exclusive file ownership | Contract-conformant components + cross-review notes. (3) §9 line ~348: replace "a team-based executor arrives in a later phase" with "the team-based executor is `/execute-team`". (4) Add one §9 design-rule line: light variants (`/hotfix`, `/chore`, `/bug`) spawn no subagents by design — weight-matching is the feature.
- **PATTERN**: workflow.md:238-271 (entry format), 320-326 (roster rows)
- **GOTCHA**: do not renumber sections (grep for stale §N refs if you do); `/execute-team` is experimental-flagged — say so in its §7 entry with the fallback
- **VALIDATE**: `grep -c '^### /' template/.claude/workflow.md` → 12 (6 existing + 6 new); `grep -c 'arrives in a later phase' template/.claude/workflow.md` → 0; `grep -c 'execute-team' template/.claude/workflow.md` → ≥3
- **VERIFY**: every new command has a §7 entry; roster row present
- **DONE**: workflow.md documents all 15 commands' GitHub interactions and the team executor's place in the subagent layer

### UPDATE template/.claude/skills/workflow/SKILL.md — enumerations

- **IMPLEMENT**: Add the six new files to BOTH enumerations: the Step 1 "All slash commands" list (lines 26-35) and the Step 3 impact-analysis checklist (lines 60-69). Keep alphabetical-ish grouping consistent with what's there.
- **PATTERN**: SKILL.md:26-35, 60-69
- **VALIDATE**: `grep -c 'commands/' template/.claude/skills/workflow/SKILL.md` → 31 (was 19; +6 in each of two lists); `grep -c 'execute-team' template/.claude/skills/workflow/SKILL.md` → 2
- **VERIFY**: both lists have all 15 command files
- **DONE**: workflow skill's lockstep checklist covers the new surface

### UPDATE template/.claude/commands/init-project.md — command enumerations

- **IMPLEMENT**: (1) Line ~145: extend the loop list `for cmd in commit continue execute plan-feature status create-prd create-rules prime` with `hotfix chore bug plan-hotfix plan-bug execute-team`. (2) Line ~548: "9 slash commands configured" → "15 slash commands configured". No label creation changes — `/bug` reuses the existing `type:bug`; `/chore` and `/hotfix` need no labels (taxonomy unchanged, deliberately: label-taxonomy changes are High Stakes).
- **PATTERN**: init-project.md:145, 548
- **GOTCHA**: init-project.md is copied VERBATIM by sync (placeholders instructional) — its `{{...}}` content is exempt from the guard; nothing special needed, just edit in template/
- **VALIDATE**: `grep -c 'execute-team' template/.claude/commands/init-project.md` → ≥1; `grep -c '15 slash commands' template/.claude/commands/init-project.md` → 1
- **VERIFY**: no `gh label create` lines added or changed
- **DONE**: fresh installs verify and report all 15 commands

### UPDATE CLAUDE.md (root, direct edit) — command count

- **IMPLEMENT**: Line 63: `# 9 slash commands (plan-feature, execute, commit, ...)` → `# 15 slash commands (plan-feature, execute, execute-team, hotfix, bug, chore, ...)`. CLAUDE.md is root-only — edit it directly; sync never touches it.
- **VALIDATE**: `grep -c '15 slash commands' CLAUDE.md` → 1
- **DONE**: repo docs match reality

### RUN sync + full battery (final)

- **IMPLEMENT**: `./scripts/sync-template.sh` then `./.claude/hooks/validate-local.sh`. Stage the regenerated `.claude/` files together with the `template/` edits.
- **VALIDATE**: `./scripts/sync-template.sh` → "OK: template synced, all placeholders resolved."; `./.claude/hooks/validate-local.sh && echo battery-green` → battery-green; `git status --porcelain .claude | grep -c '^ M\|^??'` → matches only the 6 new + 3 updated synced files
- **VERIFY**: `ls .claude/commands/*.md | wc -l` → 15; `grep -c 'nicholasmartin/nexus' .claude/commands/execute-team.md` → 0; `grep -rn '{{' .claude/commands/execute-team.md` → 0 hits (placeholders resolved in root copy)
- **DONE**: dogfood installation runs the shipped product; battery green

---

## TESTING STRATEGY

No test framework — validation is structural (grep assertions per task above) plus behavioral dogfooding.

### Unit Tests

n/a — per-task grep assertions serve this role (see VALIDATE lines).

### Integration Tests

The sync + battery run is the integration test: placeholders resolve, no drift, shell syntax clean, root-only boundary intact.

### Edge Cases

- `/chore` on a task that turns out to be a real bug → its deviation rule must route to `/bug`, not silently grow
- `/hotfix` with no existing issue → skips board entirely (must not create an issue)
- `/bug` on a project with no test framework → manual-repro path, still gated red-before-fix
- `/execute-team` with the flag unset → stops with the fallback message, does not attempt to spawn
- A plan with "Single-component feature — no cross-component contracts" handed to `/execute-team` → Step 3's "confirm it's complete" should bounce it to `/execute`

## VALIDATION COMMANDS

### Level 1: Syntax & Style

```bash
for f in scripts/*.sh .claude/hooks/*.sh .claude/scripts/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
grep -c '^````' template/.claude/commands/plan-feature.md   # expect 2
```

### Level 2: Structural/Contract Tests

```bash
ls template/.claude/commands/*.md | wc -l                    # expect 15
grep -c 'nicholasmartin/nexus' template/.claude/commands/execute-team.md   # expect 0
grep -c '^### /' template/.claude/workflow.md                # expect 12
grep -c 'commands/' template/.claude/skills/workflow/SKILL.md # expect 31
grep -c 'Recommended executor' template/.claude/commands/plan-feature.md  # expect ≥1
grep -rEn '\{\{[A-Z_]+\}\}' template/.claude/commands/{chore,hotfix,bug,plan-bug,plan-hotfix,execute-team}.md | grep -vE 'REPO_OWNER|REPO_NAME|PROJECT_NAME|PROJECT_NUMBER|PROJECT_ID|FIELD_ID|STATUS_|PRIORITY_'   # expect no output
```

### Level 3: Integration

```bash
./scripts/sync-template.sh                                   # expect OK line
./.claude/hooks/validate-local.sh && echo battery-green      # expect battery-green
grep -rl '{{' .claude/ | grep -v init-project.md | wc -l     # expect 0
```

### Level 4: Manual Validation

- Run `/chore fix a typo in AGENTIC-EVOLUTION.md` end-to-end; count tool calls vs a `/execute` run (PRD: ≤25%)
- Run `/bug <N>` on a real open issue; confirm the red repro lands before the fix
- With the flag unset, run `/execute-team .agents/plans/EXAMPLE.md` — confirm the stop-with-fallback message
- (Walkthrough, per PRD) one multi-component feature built via `/execute-team` from a contract-rich plan

## ACCEPTANCE CRITERIA

- [ ] Six new command files exist in `template/.claude/commands/` and (post-sync) in `.claude/commands/`
- [ ] `/hotfix` never touches the Phase field; `/chore` never touches GitHub; `/bug` gates fix on a red repro
- [ ] `/execute-team` is fully genericized (zero nexus refs), flag-gated, with `/execute` fallback documented
- [ ] `/plan-feature` reports a recommended executor keyed off INTEGRATION CONTRACTS
- [ ] workflow.md §7 covers all 15 commands; §9 names `/execute-team` as the contracts consumer
- [ ] Workflow skill, init-project.md, CLAUDE.md enumerations/counts updated
- [ ] The 9 existing commands: names and calling conventions unchanged (only plan-feature.md and init-project.md have in-scope edits)
- [ ] No label-taxonomy changes
- [ ] Sync green, battery green, zero unresolved placeholders

## COMPLETION CHECKLIST

- [ ] All tasks completed in order; each VALIDATE passed immediately
- [ ] All four validation levels executed successfully
- [ ] Manual validation confirms weight-matching behavior
- [ ] `.agents/learnings/level-3.md` written + walkthrough + sign-off (level gate — required before Level 4 planning)
- [ ] Acceptance criteria all met

---

## NOTES

**Design decisions (medium-stakes, made in planning — flag at execution if you disagree):**

1. **`/execute-team` ports as a single command file**, not a skill directory. Commands and skills are a merged system now (identical frontmatter incl. `disable-model-invocation`); the source SKILL.md is self-contained at 212 lines; all other executors live in `commands/`; the workflow skill's checklist enumerates `commands/`; and dropping README/example-plan sheds nexus-specific baggage. Attribution to coleam00 (MIT) stays in the file.
2. **No new labels.** Adding `type:chore`/`type:hotfix` would be a High-Stakes taxonomy change per CLAUDE.md — and unnecessary: `/chore` has no issue linkage, `/hotfix` rides whatever label its issue already has, `/bug` reuses `type:bug`.
3. **`/hotfix` hands off with `fix:`** — `hotfix:` is not a Conventional Commits type (verified against the v1.0.0 spec).
4. **Weight ladder is the invariant to protect:** `/chore` (no GitHub, no plan) < `/hotfix` (issue optional, Status only) < `/bug` (issue-driven, test-first) < `/execute` (plan + verifiers) < `/execute-team` (plan + contracts + teammates). Each new command names its escalation path.

**Gate reminder:** Level 2's learning gate (epic #10 sign-off) is a hard gate — this plan was produced *as part of* the Level 2 walkthrough (level-2.md "See it yourself" step 1), but **execution must not start until the Level 2 sign-off is recorded**.

**Verified external facts the executor should not re-litigate:** agent-teams flag unchanged (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`); `TeamCreate`/`TeamDelete` removed; in-process display default since v2.1.179 (tmux optional); `$ARGUMENTS[N]` 0-based; one team per session, no nested teams; teammates don't inherit lead conversation. Source anchors in CONTEXT REFERENCES.
