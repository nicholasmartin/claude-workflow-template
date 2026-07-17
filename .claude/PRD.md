# PRD: Agentic Evolution of the Claude Workflow Template

**Version:** 1.1
**Date:** 2026-07-17
**Status:** Active — amended at Level 5 close (Level 6 re-cut to ship layer, triage → Level 7; see §15 decisions log)
**Sources:** `AGENTIC-EVOLUTION.md`, IndyDevDan "Forget Loop Engineering" transcript (`transcription.md`), Level 1 design discussion (2026-07-14), ship-layer design discussion (2026-07-17)

---

## 1. Executive Summary

The claude-workflow-template today is a **Level 0** system: a set of slash commands (`/plan-feature`, `/execute`, `/commit`, `/continue`) that one engineer drives sequentially through one Claude Code session, with GitHub Issues/Projects as the tracking layer. It works, but every deterministic check runs only if the agent remembers to run it, every phase blocks on a single agent's context, and every ticket gets the same heavyweight treatment.

This project evolves the template through **seven levels** toward IndyDevDan's "AI Developer Workflow" model — composing the three actors of value creation (engineers at the ends, agents in the middle, deterministic code as the glue) — while staying entirely on the Claude Code subscription using native primitives: hooks, subagents, worktrees, and scheduled sessions. No Agent SDK, no API bill.

The repo is its own first customer: every improvement is built in `template/` (the product), synced to the root installation (the dogfood), and used to manage the next level's work. **The MVP goal:** a solo developer reviews an auto-prepared plan, hits `/execute`, and the workflow ships validated work — while they're already reviewing the next plan in another terminal.

**A defining requirement of this project:** the owner must *understand* every level before the next begins. Each level ends with a **learning step** — a written learning doc plus a live guided walkthrough — that acts as a **hard gate**: no sign-off, no next level.

---

## 2. Mission

Turn the workflow template into a system that builds the system — one level at a time, with the engineer's understanding growing at the same rate as the automation.

### Core Principles

1. **Code for conditions, agents for judgment.** Every pass/fail check (lint, typecheck, placeholder scan) moves out of prompt prose into hooks and scripts. Agents keep only what needs thinking: fixes, synthesis, decisions.
2. **KISS — each level is the simplest version that works.** Ship the level, learn it, then scale. No level builds machinery a later level "will need."
3. **Understanding is a deliverable.** A level is not done when the code works; it is done when the owner can explain what changed and demonstrate the new behavior. Learning docs + walkthrough are acceptance criteria, not documentation garnish.
4. **template/ is the source of truth.** All edits land in `template/`, sync to the root installation via `scripts/sync-template.sh`, and are tested by dogfooding before they ship to users.
5. **Engineer at both ends.** Every level preserves the two human constraint points: plan approval and review. Automation grows in the middle only.

---

## 3. Target Users

| Persona | Description | Needs |
|---|---|---|
| **The owner (primary)** | Nick — solo developer, template maintainer, Claude Code subscription user. Comfortable with bash, git, `gh`; learning agentic-engineering patterns hands-on. | Ship faster without losing understanding of the system; keep costs at subscription level; reuse everything across other projects. |
| **Template users (secondary)** | Developers who copy `template/` into their own projects. Mixed skill levels; muscle memory around the 9 existing commands. | Backward compatibility, graceful degradation on any stack (the template is language-agnostic), clear docs. |
| **The agents (tertiary)** | Claude Code sessions and subagents executing the commands. | Unambiguous instructions, deterministic feedback loops, plumbing they can't fumble (scripts instead of re-derived `gh` choreography). |

---

## 4. MVP Scope

### In Scope

**Core Functionality**
- [ ] Level 1: Deterministic validation hooks (post-edit lint, stop-gate battery, pre-commit scan)
- [ ] Level 2: Parallel scout subagents in `/plan-feature` (+ Integration Contracts plan section); verification subagent in `/execute`
- [ ] Level 3: Weight-matched command variants (`/hotfix`, `/chore`, `/bug`, `/plan-bug`, `/plan-hotfix`) plus `/execute-team` ported from nexus as the heavy-end executor
- [ ] Level 4: Worktree isolation (`/execute-isolated`)
- [ ] Level 5: Multi-session coordination conventions (GitHub board as shared blackboard, worktree ownership labels)
- [ ] Level 6: Ship layer — `/merge` and `/pr` as explicit ship-time endings for branch work; `/execute-isolated` stops at the commit seam; `/commit` closes issues only on the default branch; `/continue` reconciles merged PRs
- [ ] Level 7: Automated triage (`/dispatch` + scheduled session that preps plans for review)

**Learning System (cross-cutting)**
- [ ] `.agents/learnings/level-N.md` written at the end of every level (what changed, why, before/after, how to observe it)
- [ ] Live guided walkthrough per level (owner watches the new machinery fire on a real example)
- [ ] Hard gate: level's epic closes only after owner sign-off; next level's planning does not start before that

**Technical**
- [ ] `.claude/settings.json` hooks configuration shipped in `template/` (green-field — none exists today)
- [ ] Hook scripts that degrade gracefully on any stack (detect eslint/tsc/etc., exit silently if absent)
- [ ] Deterministic plumbing scripts (`board-state.sh`, `move-issue.sh`, issue-creation helper) replacing embedded `gh` choreography
- [ ] `scripts/sync-template.sh` keeps root installation current (already built during self-install)

**Integration**
- [ ] All work tracked on board #18; Phase field N = Level N
- [ ] `/init-project` updated to install hooks/scripts into new projects
- [ ] `workflow.md` + `workflow` skill updated in lockstep with every system change (existing guardrail)

### Out of Scope

- [ ] Anthropic Agent SDK / API-based orchestration (subscription-only constraint)
- [ ] Remote/cloud sandboxes (worktrees are the isolation story)
- [ ] CI/CD pipeline integration (GitHub Actions) — future consideration
- [ ] Multi-user / team coordination features — the template stays solo-dev-first
- [ ] Zero-touch shipping (Dan's "drop engineering review") — the engineer review gate is permanent at every level
- [ ] Shipping learning docs in `template/` — they document this repo's journey, not the product

---

## 5. User Stories

1. **As the owner, I want lint failures surfaced automatically after every agent edit,** so that the tightest loop (build → lint → build) runs on deterministic code instead of the agent remembering.
   *Example: agent writes a `.ts` file with an unused import; the PostToolUse hook reports it within ~300ms; the agent fixes it without being asked.*

2. **As the owner, I want the agent unable to end its turn while validations fail,** so that "done" always means verified.
   *Example: agent believes it finished; the Stop hook runs `tsc --noEmit --incremental`; two type errors come back; the turn continues until green.*

3. **As the owner, I want a learning doc and walkthrough after each level,** so that I understand the system I now own before it grows further.
   *Example: after Level 1 I'm shown a deliberately broken edit, watch the hook catch it, and read `level-1.md` explaining every new file.*

4. **As the owner, I want planning research done by parallel scouts,** so that plans are more thorough and faster to produce.
   *Example: `/plan-feature` fans out codebase-patterns, external-docs, and testing-patterns scouts concurrently; the main session synthesizes.*

5. **As the owner, I want a typo fix to cost typo-fix ceremony,** so that workflow weight matches ticket weight.
   *Example: `/chore fix README typo` — single agent, one validation pass, `chore:` commit, no plan file, no board Phase.*

6. **As the owner, I want two features progressing in parallel without file conflicts,** so that my throughput isn't bounded by one working tree.
   *Example: `/execute-isolated plan-A.md` in terminal 1, `/hotfix` on issue #67 in terminal 2, each in its own worktree, board keeps them coordinated.*

7. **As the owner, I want to choose merge-or-PR at ship time, per branch,** so that the same workflow serves my solo repos and the client repos where I can't merge PRs — with no install-time mode deciding for me.
   *Example: `/execute-isolated` finishes on the branch; I run `/merge` when the next task needs this work under it, or `/pr` when the repo requires review — and if the PR sits unmerged, I stack the next branch on top inside the same worktree.*

8. **As the owner, I want a scheduled session to triage the board and prep the next plan,** so that my morning starts at the review constraint, not the research phase.
   *Example: overnight `/dispatch` picks the top Ready issue, routes to the right planner, drops a plan file, and stops for my approval.*

9. **As a template user, I want everything to work on my stack or get out of the way,** so that adopting the template never breaks my project.
   *Example: hooks in a Python repo detect no eslint/tsc and exit 0 silently.*

---

## 6. Core Architecture & Patterns

### The Three-Actor Model (Dan → this template)

| Actor | Where it lives here |
|---|---|
| **Engineer** | Plan approval, learning-gate sign-off, commit review — the two ends, never the middle |
| **Agents** | Slash-command sessions + subagents (scouts, verifier) via the `Agent` tool |
| **Code** | Hooks (`.claude/settings.json`), plumbing scripts (`scripts/`), inline `` !`...` `` command bash, sync script |

### The Extraction Rule

For every instruction in a command file: **does it tell the agent how to think, or how to type?**
- *How to think* (deviation rules, prioritization, report formats) → stays in the command, verbatim.
- *How to type* (gh choreography, greps, validation commands) → becomes one of:
  1. **Hook** — harness-triggered, agent never invokes it (loop conditions: post-edit lint, stop battery, pre-commit scan)
  2. **Script** — agent-invoked with judgment inputs (`./scripts/board.sh move 42 "In Progress"`)
  3. **Inline `!` bash** — harness runs it before the agent thinks (fixed data gathering in `/continue`, `/status`)

### Two-Tier Validation

| Tier | Check | Cost | Trigger | Fail behavior |
|---|---|---|---|---|
| Per-edit | single-file eslint (`--cache`) | ~100–300ms | `PostToolUse` on Write\|Edit | **Advisory** — report, never block (mid-flight edits are legitimately broken) |
| Per-turn | `tsc --noEmit --incremental`, test battery | seconds | `Stop` hook | **Blocking** — turn cannot end until green |
| Per-ship | placeholder scan (TODO/FIXME/empty fn/empty catch/`.only`/`.skip`) | ms | pre-commit | **Warn** — agent relays, user decides |

### Repository Layout (target state)

```
/
├── template/                  # THE PRODUCT
│   ├── .claude/
│   │   ├── settings.json      # hooks config (Level 1, new)
│   │   ├── hooks/             # hook scripts (Level 1, new)
│   │   ├── commands/          # 9 existing + ~6 new variants (Level 3, 4, 6)
│   │   ├── skills/workflow/   # meta-skill, updated every level
│   │   └── workflow.md        # system source of truth, updated every level
│   ├── .agents/plans/
│   └── scripts/               # plumbing: board-state, move-issue, ... (new)
├── .claude/                   # live installation (generated by sync)
├── .agents/
│   ├── plans/                 # real plan files, one+ per level
│   └── learnings/             # level-N.md learning docs (repo-only)
├── scripts/
│   ├── sync-template.sh       # template -> root sync
│   └── workflow.env           # this repo's captured board IDs
└── AGENTIC-EVOLUTION.md       # the conceptual roadmap
```

### The Level Lifecycle (repeats 7 times)

```
/plan-feature "Level N: <title>"          → plan file + GitHub epic (Phase N)
  ↓ owner approves plan                   [HUMAN GATE 1]
/execute .agents/plans/level-N-*.md       → implementation in template/ + sync
  ↓ validations pass
write .agents/learnings/level-N.md        → what changed / why / how to observe
live walkthrough                          → owner watches new machinery fire
  ↓ owner signs off                       [HUMAN GATE 2 — HARD]
/commit                                   → closes epic, board Phase N → Done
  → only now may /plan-feature "Level N+1" begin
```

---

## 7. Features (Level by Level)

### Level 1 — Deterministic Validation Hooks

**Problem:** every check in `/execute` and `/commit` runs only if the agent obeys prose.
**Solution:** move the three loop *conditions* into the harness.

| Deliverable | Detail |
|---|---|
| `PostToolUse` hook | Fires on Write\|Edit only; reads `file_path` from stdin JSON; single-file `eslint --cache`; skips non-code files; advisory |
| `Stop` hook | Full validation battery (`tsc --noEmit --incremental`, tests if cheap); blocking; failure output feeds back into the turn |
| Pre-commit scan | Existing TODO/FIXME/empty-fn greps + empty `catch` + `.only`/`.skip`; warn-don't-block preserved |
| Sync-drift check (this repo only) | Pre-commit: if the commit touches `template/`, verify `.claude/` matches a fresh sync output; block with "run ./scripts/sync-template.sh" if drifted. Enforces the CLAUDE.md golden rule with code instead of prose |
| Graceful degradation | Hooks detect project tooling; exit 0 silently when absent (language-agnostic template) |
| Command trims | `/execute`: step 3c deleted, step 5 → one-line contract statement (~179 → ~90 lines). `/commit`: placeholder section → relay-the-warning only |
| Ripple updates | `/init-project` installs hooks; `workflow.md` + `workflow` skill document the hook layer |
| Secondary (separate commit) | Plumbing scripts: `board-state.sh`, `move-issue.sh`, issue-creation helper; `/continue`+`/status` gather steps become inline `!` bash |

### Level 2 — Parallel Subagents

- `/plan-feature` Phase 2/3 refactor: three concurrent scouts (codebase patterns / external research / testing patterns), main session synthesizes
- `/plan-feature` plan template gains an **Integration Contracts** section (exact URLs, JSON shapes, error formats, cross-cutting assignments) — prepares plans for Level 3's `/execute-team`
- `/execute`: post-task **verification subagent** independently checks the plan's Observable Truths, reports pass/fail without polluting builder context

### Level 3 — Weight-Matched Command Variants

The full executor spectrum, light to heavy — workflow weight matches ticket weight:

- **Light:** `/hotfix` (speed-first, no PRD/plan ceremony), `/chore` (no issue linkage, `chore:` commit), `/bug` (failing-test-first), `/plan-bug`, `/plan-hotfix`
- **Heavy:** `/execute-team` — ported from the nexus project (`.claude/skills/execute-team/`, itself adapted from Cole Medin's `build-with-agent-team`). A lead agent distributes integration contracts from the plan, spawns real Claude Code teammate agents (experimental agent-teams feature, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) with exclusive file ownership, facilitates contract diffs + cross-review, runs end-to-end validation, hands off to `/commit`. Port work: genericize nexus-specific repo refs to `{{PLACEHOLDER}}`s, align board lifecycle with this template's workflow.md, document the fallback to `/execute` when agent teams are unavailable
- `/plan-feature` recommends which executor fits each plan (single-domain → `/execute`; multi-component with interface boundaries → `/execute-team`)
- Each light variant ~half the size of `/execute`; existing commands unchanged (muscle-memory preservation)

### Level 4 — Worktree Isolation

- `/execute-isolated <plan>` wrapping `EnterWorktree`; rollback via `ExitWorktree`; enables N terminals × N worktrees

### Level 5 — Cross-Session Coordination

- Convention only: board = shared blackboard; `worktree:<name>` labels/comments mark session ownership; `/continue` respects in-progress claims

### Level 6 — Ship Layer (`/merge` + `/pr`)

> Re-cut 2026-07-15 (was: automated triage → now Level 7); design finalized 2026-07-17.
> **No `SHIP_FLOW` flag** — an earlier sketch put a merge|pr mode in workflow.env; rejected.
> Landing is a **ship-time choice per branch**, made at the seam *"work committed on a
> branch" → "work lands on the default branch."* Governing invariant: **an issue closes
> only when its work reaches the default branch.**

- `/execute-isolated` **stops at the seam**: ends after `/commit` on the worktree branch — branch + worktree kept, issue open, claim held; reports the two endings. Auto merge/cleanup (old Step 7) is removed
- `/commit` closes issues **only on the default branch**. On a feature branch: commit, comment progress, check off AC, never close — point at `/merge`/`/pr`. Unchanged on master. Optional `--close` escape hatch
- **`/merge` (new) — local ending**, for "the next task needs this work under it": safety checks (clean main tree, merges serialized across sessions), **branch-protection guard** (protected default branch → stop, redirect to `/pr` before anything happens), `git merge --no-ff`, close issue + board → Done + release claim, push. Branch/worktree deletion is an **explicit final step, never a side effect** (default keep; `/continue` GCs fully-merged branches)
- **`/pr` — remote ending**, ported from `~/projects/digi-tal/claude-workflow/.claude/commands/pr.md`: push branch, open PR (**never merges**, consent-only rebase, `--reviewer`, `--draft`), `Closes #<issue>` fires on merge, board → **In Review** (new Status option). Branch + worktree stay alive for review feedback
- `/continue` **reconciles merged PRs**: pull master, board → Done, release claim, offer branch/worktree cleanup (`git branch -D` — squash-merge defeats git's own merged check; the PR's merged state is the source of truth). **Stack-aware**: never delete a branch with local descendants — offer `git rebase --onto origin/<default> <A> <B>` instead
- **Stacking documented as a pattern, not machinery**: continue on top of PR'd-but-unmerged work via `git checkout -b` inside the same worktree (worktree-per-stack); one `--onto` rebase after each upstream squash-merge
- Ripple: board gains "In Review" Status option (and a Phase 7 option); `workflow.md` §ship-layer; `/init-project` label/status setup updated

### Level 7 — Automated Triage

- `/dispatch`: reads board, classifies top Ready issue by `type:` label, routes to the matching planner, drops plan file, **stops for review**
- Scheduled session (CronCreate / `schedule` skill) runs `/dispatch` each morning
- The engineer's two constraint points are preserved by design: dispatch never executes, only preps

### Cross-Cutting: The Learning System

Every level ships `.agents/learnings/level-N.md`:

```markdown
# Level N: <title> — What Changed and Why
## The gap this closes          (from AGENTIC-EVOLUTION.md)
## New/changed files            (before → after, with diffs where useful)
## How information flows now    (the new loop/handoff, diagrammed)
## See it yourself              (exact steps to trigger the new behavior)
## What to watch out for        (failure modes, escape hatches)
## Walkthrough log              (what we demonstrated live, questions raised)
```

Followed by a live walkthrough (deliberately trigger the new machinery on a real example) and owner sign-off. **Sign-off closes the level's epic; nothing from Level N+1 starts before it.**

---

## 8. Technology Stack

| Technology | Version/Detail | Purpose |
|---|---|---|
| Claude Code | current (subscription) | The entire agent runtime: sessions, subagents, hooks, worktrees, scheduling |
| Markdown | — | Commands, skills, rules, docs — the product itself |
| Bash | 4+ (WSL2/Linux; Git Bash compatible where possible) | Hooks, plumbing scripts, sync |
| GitHub CLI (`gh`) | 2.46+ (built-in `--jq`) | Issues, board, labels, GraphQL mutations |
| GitHub Issues/Projects v2 | Board #18 | Shared state / kanban queue |
| git worktrees | via `EnterWorktree` | Level 4–5 isolation |

**Explicitly not used:** Agent SDK, Anthropic API, external CI, node dependencies in the template itself. Hook scripts may *call* project-local tools (eslint, tsc, pytest) when present.

---

## 9. Security & Configuration

- **Auth:** everything rides on the user's existing `gh auth` session; no tokens stored
- **Configuration:** `scripts/workflow.env` holds board/field IDs (not secrets — safe to commit); `{{PLACEHOLDER}}` convention for template distribution; `.claude/settings.json` for hooks
- **Hook safety:** hooks run arbitrary project commands — template ships only well-known tools (eslint/tsc/prettier detection), documented so users can audit before adopting
- **Out of scope:** secrets management, sandboxing beyond worktrees, multi-user permissions

---

## 10. API Specification

Not applicable — no service endpoints. The "API" of this product is its command surface (slash commands), hook contracts (stdin JSON → exit code + stdout), and script interfaces (documented per-script in Level 1).

---

## 11. Success Criteria

**MVP success definition:** *A new ticket lands; a plan is waiting for review (eventually auto-prepped); the owner approves it; the workflow ships validated work while the owner reviews the next plan in another terminal — and the owner can explain every moving part.*

**Functional requirements**
- [ ] An agent edit that violates lint is reported to the agent within 1s, without prompting (L1)
- [ ] An agent turn cannot end with failing typecheck/tests (L1)
- [ ] A commit with `.only` in a test file triggers a warning before committing (L1)
- [ ] `/plan-feature` research phase runs ≥3 concurrent scouts (L2)
- [ ] Every executed task is independently verified by a subagent (L2)
- [ ] A chore ships with ≤25% of the tool calls a feature requires (L3)
- [ ] A multi-component feature builds via agent team from a contract-rich plan, with zero integration mismatches at contract-diff time (L3)
- [ ] Two plans execute simultaneously with zero file conflicts (L4–5)
- [ ] `/commit` on a feature branch never closes an issue; the issue closes at `/merge` or PR merge, after the work is on the default branch (L6)
- [ ] `/merge` on a repo with a protected default branch stops and redirects to `/pr` before merging anything (L6)
- [ ] A branch with a local descendant survives PR-merge reconciliation; `/continue` offers the stack rebase instead of deleting it (L6)
- [ ] A scheduled session preps a reviewable plan with no human at the keyboard (L7)
- [ ] All 7 learning docs exist and each level has a logged sign-off (cross-cutting)

**Quality indicators**
- [ ] Hooks add <500ms p95 to edit operations; zero cost on non-code files
- [ ] All hooks/scripts no-op gracefully on a stack without JS tooling
- [ ] Root installation never drifts from `template/` (sync check passes at every commit)
- [ ] Existing 9 commands keep their names and calling conventions throughout

---

## 12. Implementation Phases

> **Phase N on board #18 = Level N.** Every phase ends with the same three deliverables: learning doc, live walkthrough, owner sign-off (hard gate). Estimates assume dogfooding overhead (each phase is built *with* the previous phase's machinery).

| Phase | Goal | Key Deliverables | Validation | Est. |
|---|---|---|---|---|
| **1 — Hooks** | Loop conditions become code | settings.json, 3 hook scripts, `/execute`+`/commit` trims, init-project/workflow.md/skill updates; then plumbing scripts (separate commit) | Deliberately broken edit → hook catches it; turn with failing tsc cannot end; `.only` warns at commit | 1–2 sessions |
| **2 — Subagents** | Scale compute on planning + verification | `/plan-feature` scout fan-out + Integration Contracts plan section, `/execute` verifier | Plan produced by parallel scouts on a real Level 3 prep issue; verifier catches a seeded defect | 1–2 sessions |
| **3 — Variants** | Weight-matched workflows, light to heavy | `/hotfix`, `/chore`, `/bug`, `/plan-bug`, `/plan-hotfix`; `/execute-team` ported from nexus | Real chore + real bug shipped through the new paths; one multi-component feature built by an agent team from a contract-rich plan | 2–3 sessions |
| **4 — Isolation** | Parallelism without conflicts | `/execute-isolated` (EnterWorktree wrapper) | Two plans executed in parallel worktrees, clean merges | 1 session |
| **5 — Coordination** | Board as shared blackboard | `worktree:` ownership convention, `/continue` awareness | 2–3 terminal live test on real issues | 1 session |
| **6 — Ship layer** | Landing becomes a ship-time choice | `/merge` (new), `/pr` (ported), `/execute-isolated` stops at the seam, `/commit` default-branch-only close, `/continue` reconcile, "In Review" Status | Real branch shipped both ways: `/merge` locally on this repo; `/pr` + stacked follow-up branch + post-squash reconcile on a PR-gated repo (or simulated via branch protection here) | 1–2 sessions |
| **7 — Triage** | Ticket → reviewable plan, unattended | `/dispatch`, scheduled morning session | Overnight run produces a correct, reviewable plan for a seeded issue | 1–2 sessions |

> Board note: Phase options on board #18 currently go to Phase 6 (`c9c4e3db`). Level 7 work
> requires adding a "Phase 7" option (via `updateProjectV2Field`) and appending it to
> `PHASE_OPTIONS` in `scripts/workflow.env` — fold this into Level 6's ripple or Level 7's setup.

---

## 13. Future Considerations

- **Zero-touch chores:** dropping engineer review for `type:chore` after the system earns trust (Dan's ZTE) — deliberately excluded now
- **GitHub Actions integration:** CI as another deterministic node feeding back into build sessions
- **Learning docs as product:** if the level-N docs prove valuable, a generalized `/walkthrough` command could ship in the template
- **Agent experts:** specialized memory/context per workflow type (Dan's "hotfix agent that knows only speed")
- **Template versioning/migration:** once users depend on hooks, a migration story for template upgrades

---

## 14. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| **Hook misfires fight the agent** (blocking mid-flight edits, false positives) | Agent thrashes, owner disables hooks, Level 1 credibility lost | Per-edit tier is advisory-only; blocking only at Stop; escape hatch documented in learning doc |
| **Template/root drift** | Dogfood stops testing the shipped product | Sync script fails loudly on unresolved placeholders; CLAUDE.md golden rule; sync check before every commit |
| **Over-engineering a level** (building for Level N+2 early) | Complexity outruns understanding — the exact failure the learning gates exist to prevent | KISS principle per level; hard gate forces digestion; plans reviewed against "simplest that works" |
| **Breaking template users** (renamed commands, changed conventions) | Muscle-memory breakage, trust loss | High-stakes protocol in CLAUDE.md: additive changes only; existing 9 commands keep names/signatures |
| **Claude Code primitive changes** (hooks API, EnterWorktree, scheduling) | Levels built on shifting sand | Hooks/scripts are thin wrappers; primitive-specific logic isolated per file; learning docs record the assumptions |
| **Agent teams are experimental** (`/execute-team` depends on an env-flagged feature that may change or regress) | Level 3's heavy executor breaks for template users | `/execute-team` documents fallback to `/execute`; feature-flag check up front with a clear message; light variants carry the level if teams are unavailable |
| **Learning steps decay into rubber stamps** | Owner loses the thread by Level 4; automation without understanding | Walkthrough requires live demonstration, not just reading; sign-off is an explicit logged act on the epic |
| **Ship-layer footguns** (merge pushed to an unprotected team repo bypassing review; reconcile deletes a branch a stack depends on; squash-merge defeats `branch -d`) | Work lands unreviewed, or local stacked work is stranded | `/merge` branch-protection guard; reconcile is stack-aware (descendant check before delete); PR merged-state, not git ancestry, is the deletion authority; keep-until-GC deletion default |

---

## 15. Appendix

**Related documents**
- `AGENTIC-EVOLUTION.md` — the conceptual level ladder this PRD operationalizes
- `transcription.md` — IndyDevDan source material
- `.claude/workflow.md` — workflow system reference (field IDs, lifecycle)
- `scripts/workflow.env` — board #18 captured IDs

**Key decisions log (2026-07-14)**
1. Learning step = doc + live walkthrough (not doc-only)
2. Learning step is a **hard gate** between levels
3. Phases map strictly 1:1 to Levels 1–6 (no re-cut) — *superseded by decision 8*
4. Level 6 is committed scope, not aspirational
5. Learning docs live in `.agents/learnings/` (repo-only, not shipped in template)
6. Script extractions are Level 1 scope but a separate commit from hooks
7. `/execute-team` (exists in nexus only, never ported here) joins Level 3 as the heavy-end executor variant; its Integration Contracts plan-section dependency lands in Level 2's `/plan-feature` refactor (decided 2026-07-14)

**Amendments (2026-07-15 / 2026-07-17)**
8. **Roadmap re-cut at Level 5 close (2026-07-15):** Level 6 = ship layer (PR handoff); automated triage moves to Level 7. Driven by consultation work on multi-dev repos. Supersedes decision 3's "no re-cut."
9. **No `SHIP_FLOW` flag (2026-07-17):** the merge|pr workflow.env mode from the original re-cut sketch is rejected — landing is a per-branch, ship-time choice (`/merge` vs `/pr` from the branch the work sits on), inferred from nothing, configured nowhere. `/commit` closes issues only on the default branch (invariant: an issue closes only when its work reaches the default branch).
10. **`/execute-isolated` ends at the commit seam (2026-07-17):** its auto merge/remove/delete tail moves into `/merge`; branch/worktree deletion becomes an explicit act (default keep, `/continue` GC), never a side effect.
