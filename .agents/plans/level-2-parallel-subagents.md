# Feature: Level 2 — Parallel Subagents

The following plan should be complete, but it's important that you validate documentation and codebase patterns and task sanity before you start implementing.

Pay special attention to the Golden Rule: **every edit lands in `template/`, then `./scripts/sync-template.sh` regenerates `.claude/`**. Never edit root `.claude/` files directly. This level changes only command prose and docs — no new scripts, no new hooks.

## Feature Description

Scale compute on the two agent-heavy phases of the workflow. `/plan-feature`'s serial research phases (codebase intelligence + external research) become a **fan-out of three concurrent scout subagents** whose reports the main session synthesizes. The plan template gains an **Integration Contracts** section — the exact interface definitions Level 3's `/execute-team` will consume (decided 2026-07-14, PRD decisions log #7). `/execute` gains a **verification subagent**: after each task, an independent read-only agent checks the task's VERIFY/DONE claims, and a final verifier checks the plan's Observable Truths before the report — two eyes catch what one doesn't, without polluting the builder's context. This is Level 2 of AGENTIC-EVOLUTION.md and Phase 2 of the PRD.

## User Story

As a solo developer running agentic workflows
I want planning research done by parallel scouts and every executed task independently verified
So that plans are faster and more thorough, and "task complete" means a second agent confirmed it — not just the builder's own claim.

## Problem Statement

`/plan-feature` today is one agent doing Phases 0–5 sequentially: the same context window that reads the board also greps the codebase, fetches external docs, and writes the plan — slow wall-clock, and research detail competes with synthesis for context. `/execute` trusts the builder to grade its own homework: the hooks (Level 1) catch deterministic failures, but nothing independently checks that a task's *claimed outcome* (VERIFY/DONE, Observable Truths) actually holds. And plans have no interface-contract convention, so Level 3's `/execute-team` would have nothing to distribute to teammates.

## Solution Statement

Rewrite two command files (prose only):

1. **`/plan-feature`**: Phase 2/3 collapse into one fan-out step — three `Agent` tool calls **in a single message** (codebase-patterns scout, external-research scout, testing-patterns scout), each with a self-contained prompt (subagents see zero conversation history) and a required report format demanding file:line evidence. The main session keeps judgment work: board context, feature understanding, ambiguity clarification (moved *before* the fan-out), synthesis, and plan writing.
2. **Plan template**: new `## INTEGRATION CONTRACTS` section between CONTEXT REFERENCES and OBSERVABLE TRUTHS, structured to meet the `execute-team` contract quality bar (exact endpoints table, named JSON shapes, event formats, error shapes, cross-cutting concerns with single owners, component file-ownership boundaries). Single-component features state "no cross-component contracts" explicitly.
3. **`/execute`**: after each task's VALIDATE passes, spawn a verifier subagent (background is fine — builder proceeds); a hard gate before Final Validation requires every verdict in and every FAIL resolved; a final verifier checks the plan-level Observable Truths.

Docs lockstep: workflow.md gains a **§Subagent Layer** section (mirroring §Hook Layer) and updated §7 command entries; workflow skill gains the matching guardrail. Sync. Learning gate closes the level.

## Feature Metadata

**Feature Type**: Enhancement
**Estimated Complexity**: Medium
**Primary Systems Affected**: template/.claude/commands/plan-feature.md, template/.claude/commands/execute.md, template/.claude/workflow.md, template/.claude/skills/workflow/SKILL.md, root .claude installation (via sync)
**Dependencies**: None external. Claude Code native `Agent` tool (Explore + general-purpose subagent types).

---

## CONTEXT REFERENCES

### Relevant Codebase Files IMPORTANT: YOU MUST READ THESE FILES BEFORE IMPLEMENTING!

- `template/.claude/commands/plan-feature.md` (Phases 2–3, lines 48–124; plan template fence, lines 151–399; Quality Criteria, lines 410–439) — Why: the serial phases being fanned out; the template gaining the contracts section; the criteria gaining contract checks
- `template/.claude/commands/execute.md` (step 3, lines 56–74; steps 5–6, lines 83–97; Deviation Rules, lines 137–159) — Why: where the verifier steps insert; deviation rules must survive verbatim
- `template/.claude/workflow.md` (§7 lines 234–270, §8 Hook Layer lines 273–308) — Why: §7 entries change; §Hook Layer is the structural model for the new §Subagent Layer
- `template/.claude/skills/workflow/SKILL.md` (Guardrails, lines 140–147) — Why: gains the subagent-layer lockstep guardrail
- `.agents/plans/level-1-deterministic-validation-hooks.md` — Why: format + rigor exemplar; the "contract-statement trim" and "docs lockstep" patterns continue here
- `.claude/PRD.md` §7 Level 2, §11 (L2 requirements), §12 Phase 2 — Why: the spec this implements

### New Files to Create

- `.agents/learnings/level-2.md` — learning doc (hard gate deliverable, root-only, NOT in template)

No new template files. This level is prose engineering inside existing commands + docs.

### Relevant Documentation YOU SHOULD READ THESE BEFORE IMPLEMENTING!

- [Subagents reference](https://code.claude.com/docs/en/sub-agents.md)
  - Sections: built-in subagents, what loads at startup, foreground/background
  - Why: exact contract the fan-out prose is written against (verified 2026-07-14, summarized below)
- [Agents overview](https://code.claude.com/docs/en/agents.md)
  - Why: parallel-approach comparison; when Explore vs general-purpose

### Verified API Facts (from claude-code-guide research, 2026-07-14)

- **Built-in subagent types**: `Explore` (read-only: Glob/Grep/Read/WebSearch/WebFetch; skips CLAUDE.md + git status for speed; cannot be resumed), `general-purpose` (all tools; loads CLAUDE.md; resumable), `Plan` (read-only, plan-mode use)
- **Context isolation**: a subagent sees NONE of the parent conversation — only its task prompt (+ CLAUDE.md for general-purpose). Every scout/verifier prompt must restate the feature, constraints, and required report format in full
- **Parallelism**: multiple `Agent` calls emitted in a single assistant message run concurrently. Command prose must say "in a single message" explicitly — prose that lists scouts as sequential steps gets serialized
- **Background by default** (v2.1.198+): subagents run in background; the parent blocks only when it needs a result. Command prose must state explicit wait-gates ("do not proceed to X until all reports are in")
- **No hard concurrency limit** documented; depth limit of 5 (irrelevant here — one level deep)
- **Result delivery**: parent receives the subagent's final message as the tool result — scouts must be told their final message IS the report

### Verified execute-team Contract Facts (from nexus scout, 2026-07-14)

Source: `~/projects/nexus/.claude/skills/execute-team/SKILL.md` (lines 76–102) + `example-plan/session-manager-plan.md` (lines 117–225).

- The skill's normal path is: "**If the plan has an Integration Contracts section** (plans from `/plan-feature` should): read it, confirm it's complete, and hand each agent its relevant slice"
- The **contract quality bar** it checks before spawning teammates:
  1. URLs exact, **including trailing slashes** (`POST /api/sessions/` vs `POST /api/sessions`)
  2. Response shapes as **explicit JSON, not prose**, with flat-vs-nested envelopes called out
  3. All event/SSE types documented with exact JSON
  4. Error responses specified (404 body, 422 body, …)
  5. Storage/state semantics explicit (e.g., accumulated vs per-chunk)
- **Cross-cutting concerns**: table with columns `Concern | Owner | Coordinates With | Detail` — each concern assigned to **exactly ONE** owner ("Orphaned cross-cutting concerns → assign each to exactly one agent")
- **File ownership**: the lead partitions files per agent as `owns` / `does NOT touch` — the plan must make component boundaries legible
- **Endpoints table** columns: `Method | Endpoint (exact) | Request Body | Response`
- **No hardcoded plan path/naming** — plan is passed as an argument; markdown; "ideally produced by /plan-feature"

### Patterns to Follow

**Contract-statement style** (from Level 1's trims, e.g. `execute.md:72`): when prose delegates to machinery, one line states the contract and points at workflow.md. The fan-out and verifier instructions should be compact contracts + a prompt spec, not walls of choreography.

**Docs lockstep** (workflow skill guardrail): command edit → workflow.md edit → SKILL.md guardrail edit → sync → verify. Level 2 adds: "Never change scout/verifier prompt specs without updating workflow.md §Subagent Layer."

**§Hook Layer as structural model** (`template/.claude/workflow.md:273-308`): tier table → per-tier detail → design rules → contracts commands rely on. §Subagent Layer mirrors this: roster table → prompt rules → gates → the contracts commands rely on.

**Self-contained scout prompts** (new, becomes the pattern): every subagent prompt contains (a) the feature description + user story, (b) the specific questions to answer, (c) the required report format with file:line evidence, (d) "your final message is the report."

---

## INTEGRATION CONTRACTS

Single-component feature — no cross-component contracts. All changes are markdown prose in one repo, executed by one agent. (This section exists in this plan because the plan was written against the new template — eat the dogfood.)

---

## OBSERVABLE TRUTHS

- Running `/plan-feature` on a real feature emits ≥3 `Agent` tool calls **in a single message** (visible in the transcript as concurrent scouts), and the resulting plan cites file:line evidence sourced from scout reports (PRD L2 req: "≥3 concurrent scouts")
- Every plan produced by the new `/plan-feature` contains an `## INTEGRATION CONTRACTS` section that either satisfies the 5-point quality bar (multi-component) or states "Single-component feature — no cross-component contracts" (single-component)
- During `/execute`, after a task completes, a verifier subagent independently checks it; a deliberately seeded defect produces `VERDICT: FAIL` with evidence, and the turn's Final Validation cannot begin until the failure is resolved (PRD L2 req: "every executed task independently verified"; Phase 2 validation: "verifier catches a seeded defect")
- The builder's context contains only verifier *verdicts*, not verifier exploration transcripts
- `template/.claude/workflow.md` documents the subagent layer; `.claude/` matches a fresh sync; `validate-local.sh` battery passes
- Existing command names, arguments, and calling conventions are unchanged (muscle-memory preservation)

## REQUIRED ARTIFACTS

- [ ] Updated `template/.claude/commands/plan-feature.md` — Phase 2/3 → scout fan-out + synthesis; ambiguity clarification moved before fan-out; plan template gains INTEGRATION CONTRACTS; quality criteria gain contract checks
- [ ] Updated `template/.claude/commands/execute.md` — per-task verifier spawn, pre-Final-Validation verdict gate, final Observable-Truths verifier; deviation rules verbatim
- [ ] Updated `template/.claude/workflow.md` — new §9 "Subagent Layer" (sections 9–11 renumbered to 10–12); §7 entries for /plan-feature and /execute updated
- [ ] Updated `template/.claude/skills/workflow/SKILL.md` — subagent-layer guardrail
- [ ] Root `.claude/` regenerated via `./scripts/sync-template.sh`
- [ ] `.agents/learnings/level-2.md` + walkthrough performed + sign-off recorded on the Phase 2 epic

## KEY LINKS

- PRD: `.claude/PRD.md` §7 Level 2, §11 (three L2 functional requirements), §12 Phase 2
- Roadmap: `AGENTIC-EVOLUTION.md` §Level 2
- GitHub epic: created by this plan's Report step (Phase 2 on board #18)
- Subagent docs: https://code.claude.com/docs/en/sub-agents.md
- Contract consumer (Level 3, reference only — do NOT port now): `~/projects/nexus/.claude/skills/execute-team/SKILL.md`

---

## IMPLEMENTATION PLAN

### Phase A: /plan-feature — scout fan-out + Integration Contracts (commit 1)

The planner refactor: fan-out prose, self-contained scout prompt specs, synthesis step, contracts section in the plan template, quality-criteria updates, workflow.md §Subagent Layer (planner half), sync.

### Phase B: /execute — verification subagent (commit 2)

Per-task verifier spawn + verdict gate + final Observable-Truths check, workflow.md §Subagent Layer (verifier half) + §7 entry, SKILL.md guardrail, sync.

### Phase C: Learning gate

`.agents/learnings/level-2.md`, live walkthrough (the real dogfood: produce the Level 3 plan with the new planner; seed a defect for the verifier), owner sign-off on the epic. **Level 3 planning is blocked until this completes.**

---

## STEP-BY-STEP TASKS

### UPDATE template/.claude/commands/plan-feature.md — Phase 2/3 → scout fan-out

- **IMPLEMENT**: Replace "Phase 2: Codebase Intelligence Gathering" and "Phase 3: External Research & Documentation" with:
  - **"Phase 2: Clarify Ambiguities"** — the existing "Clarify Ambiguities" block (currently at the end of Phase 2, lines 95–99) moves here, *before* any fan-out: asking the user after burning three scouts wastes their work. Keep its text intact.
  - **"Phase 3: Parallel Intelligence Gathering (scout fan-out)"** — instruct: "Spawn all three scouts as `Agent` tool calls **in a single message** so they run concurrently. Subagents see none of this conversation — each prompt below must be sent complete, with the feature description filled in." Then three scout prompt specs:
    1. **Codebase-patterns scout** (`subagent_type: Explore`): project structure/frameworks, similar implementations, naming + error-handling + logging conventions, integration points (files to update, where new files go), anti-patterns. Prompt tells it to read CLAUDE.md and any path-scoped rules (Explore skips them by default). Report format: files with line ranges + why each matters, verbatim pattern snippets, integration-point list.
    2. **External-research scout** (`subagent_type: general-purpose`): current library versions, official docs with section anchors, implementation examples, gotchas/breaking changes relevant to the feature. Report format: links with anchors + "Why" per link + a "verified facts" list (things confirmed against docs, not assumed).
    3. **Testing-patterns scout** (`subagent_type: Explore`): test framework + organization, exemplar test files to mirror, runnable validation commands (lint/typecheck/test invocations discovered from project config), `.claude/docs/` header scouting (read each doc's Purpose/When-to-use header; report which are relevant). Report format: exemplar files with line refs, exact non-interactive commands.
  - Every prompt spec ends with: "Your final message is your report — return the structured findings, not a narrative of your process."
  - **"Phase 4: Synthesis"** (old Phase 4 "Deep Strategic Thinking" absorbs this, renumber if needed): wait for all three reports before proceeding; cross-check them against each other; **spot-check load-bearing claims** — before a scout's file:line reference becomes a plan cornerstone, read those lines yourself; surface any *new* ambiguities the scouts uncovered to the user now. Keep the existing "Think Harder About" and "Design Decisions" content verbatim.
- **PATTERN**: contract-statement style from `execute.md:72`; prompt-spec completeness per Verified API Facts above
- **GOTCHA**: prose that lists the scouts as numbered *steps* gets executed serially — the "single message" instruction is the load-bearing line. Do not renumber/rename the command's phases in ways that break the Report step's references. Keep Phase 0/1 untouched.
- **VALIDATE**: `grep -n 'single message' template/.claude/commands/plan-feature.md` → ≥1 hit; `grep -c 'subagent_type' template/.claude/commands/plan-feature.md` → ≥3
- **VERIFY**: read the rewritten phases end-to-end: each scout prompt is self-contained (feature restated, report format demanded); clarification precedes fan-out
- **DONE**: Phases 2–4 restructured; no scout depends on conversation context

### UPDATE template/.claude/commands/plan-feature.md — plan template gains INTEGRATION CONTRACTS

- **IMPLEMENT**: Inside the plan-template fence, insert `## INTEGRATION CONTRACTS` between "Patterns to Follow" (end of CONTEXT REFERENCES) and `## OBSERVABLE TRUTHS`:
  - Lead instruction: "If the feature spans multiple components (backend + frontend, service + client, …), this section is the **authoritative interface definition** — all components MUST conform exactly, and the executor verifies alignment before integration. If single-component, state: `Single-component feature — no cross-component contracts.` and delete the subsections."
  - Subsections (mirroring the execute-team quality bar exactly):
    - **Component Boundaries** — table `Component | Owns (files/dirs) | Must Not Touch`
    - **Interface Contract** — table `Method | Endpoint (exact) | Request Body | Response`; note: "URLs exact, including trailing slashes"
    - **Data Shapes** — named shapes as explicit JSON, not prose; call out flat vs nested envelopes
    - **Events / Streaming** — every event type with exact JSON, or "None"
    - **Error Shapes** — status codes + error body per failure mode
    - **State & Storage Semantics** — explicit (e.g., accumulated vs per-chunk)
    - **Cross-Cutting Concerns** — table `Concern | Owner | Coordinates With | Detail`; rule: "each concern has exactly ONE owner"
- **PATTERN**: nexus `example-plan/session-manager-plan.md` lines 117–225 (see Verified execute-team Contract Facts)
- **GOTCHA**: the plan template lives inside a ```` ```markdown ```` fence (lines 151–399). Example JSON blocks inside the new section would need nested fences, which close the outer fence. **Upgrade the outer fence to four backticks (`````markdown` → ```` ````markdown ````)** at both ends, then inner triple-backtick fences are safe. Verify the file still renders (no orphan fences).
- **VALIDATE**: `grep -c '^````' template/.claude/commands/plan-feature.md` → 2; `grep -n 'INTEGRATION CONTRACTS' template/.claude/commands/plan-feature.md` → inside the template fence
- **VERIFY**: the section satisfies all 5 quality-bar points + single-owner cross-cutting rule + component boundaries
- **DONE**: template section present; fences balanced

### UPDATE template/.claude/commands/plan-feature.md — quality criteria + success metrics

- **IMPLEMENT**: ADD to Quality Criteria a "Contract Completeness" checklist group: interface URLs exact (trailing slashes); shapes as explicit JSON; events + errors specified; every cross-cutting concern has one owner; single-component plans say so explicitly. ADD to Context Completeness: "Scout reports synthesized; load-bearing file:line claims spot-checked." Leave existing criteria intact.
- **VALIDATE**: `grep -n 'Contract Completeness' template/.claude/commands/plan-feature.md` → 1 hit
- **DONE**: a plan can be graded for team-readiness from the command file alone

### UPDATE template/.claude/workflow.md — §Subagent Layer (planner half) + §7 /plan-feature entry

- **IMPLEMENT**: INSERT new section 9 "Subagent Layer (Scaled Compute)" after §8 Hook Layer; RENUMBER current §9–11 → §10–12. Content (mirror §Hook Layer's structure):
  - Roster table: `Command | Subagent | Type | Purpose | Result` — `/plan-feature`: 3 scouts (codebase-patterns/Explore, external-research/general-purpose, testing-patterns/Explore) → structured reports the main session synthesizes. (/execute rows added in Phase B.)
  - Design rules: parallel subagents are spawned in ONE message; subagent prompts are self-contained (no conversation context leaks in); scout reports must carry file:line evidence; the main session owns judgment (clarification, synthesis, plan writing) — scouts own retrieval; Explore for read-only research, general-purpose when web + project rules both matter.
  - The Integration Contracts convention: what the plan section contains, the 5-point quality bar, and that Level 3's `/execute-team` is its consumer.
  - Rule: changes to scout/verifier prompt specs go through the `workflow` skill and update this section in the same change.
  - UPDATE §7 `/plan-feature` entry: mention scout fan-out under "Reads", contracts section under "Creates".
- **GOTCHA**: renumbering — check for any cross-references to "section 9/10/11" elsewhere in workflow.md and in commands (grep before assuming there are none)
- **VALIDATE**: `grep -n 'Subagent Layer' template/.claude/workflow.md` → section exists; `grep -rn 'section 10\|§10\|section 11' template/.claude/ | grep -v workflow.md` → no stale references
- **DONE**: workflow.md again fully describes the system (planner half)

### RUN sync + validate (closes Phase A)

- **IMPLEMENT**: `./scripts/sync-template.sh`; run the battery.
- **VALIDATE**: `./.claude/hooks/validate-local.sh` → exit 0; `diff <(grep -c '' template/.claude/commands/plan-feature.md) <(grep -c '' .claude/commands/plan-feature.md)` → identical line counts
- **DONE**: root installation current. **Commit Phase A** (`feat(plan-feature): parallel scout fan-out + Integration Contracts section`). NOTE: this session was launched with the OLD root copy — the new planner prose takes effect next session; the walkthrough (Phase C) is where it first runs for real.

### UPDATE template/.claude/commands/execute.md — verification subagent (Phase B)

- **IMPLEMENT**:
  - ADD to step 3 (task loop), after implementation, a new sub-step **"c. Spawn the task verifier"**: after the task's VALIDATE passes, spawn one verifier subagent (`subagent_type: Explore`). The prompt must contain, verbatim: the task block (ACTION/IMPLEMENT/VERIFY/DONE lines), the exact file paths the task touched, and any Observable Truths the task contributes to. Instruction to the verifier: "Independently confirm the VERIFY and DONE claims with fresh eyes — read the artifacts; run the task's VALIDATE command if it is read-only/idempotent. Do not trust the builder's claims. Your final message: `VERDICT: PASS` or `VERDICT: FAIL — <evidence with file:line>`, nothing else on PASS." Builders may proceed to the next task while verifiers run in the background.
  - ADD a gate line at the top of step 5 (Final Validation): "**Verdict gate:** do not begin Final Validation until every task verifier has reported and every FAIL is fixed and re-verified."
  - ADD to step 6 (Final Verification): spawn one final verifier (Explore) with the plan's complete OBSERVABLE TRUTHS section: independently confirm each truth, report per-truth PASS/FAIL. Unresolved FAILs block the output report's "Ready for Commit" claim.
  - Deviation Rules, pre-flight, and the Output Report structure stay verbatim; ADD one line to the Output Report: a "Verification" subsection listing per-task verdicts + the final Observable-Truths result.
- **PATTERN**: contract-statement style (`execute.md:72,85`); verifier prompt self-containment per Verified API Facts
- **GOTCHA**: (1) Background verifiers race the builder's next edits — the prompt pins the exact files/claims of *its* task, so later unrelated edits don't confuse it. (2) VALIDATE commands that mutate state (migrations, installs) must not be re-run by the verifier — hence "read-only/idempotent" qualifier. (3) Do NOT let the verifier fix anything (Explore can't write — that's the point: report, don't repair). (4) Hooks already own deterministic checks — the verifier checks *claims*, not lint; don't duplicate the Stop battery in verifier prose.
- **VALIDATE**: `grep -c 'VERDICT' template/.claude/commands/execute.md` → ≥2; `grep -c 'Fix bugs inline' template/.claude/commands/execute.md` → 1 (deviation rules intact)
- **VERIFY**: read the full task loop: implement → hook feedback → VALIDATE → spawn verifier → next task; gate before step 5; final verifier in step 6
- **DONE**: every task independently verified; builder context stays clean (verdicts only)

### UPDATE template/.claude/workflow.md + SKILL.md — verifier half + guardrail (Phase B)

- **IMPLEMENT**: ADD to §9 Subagent Layer roster: `/execute` per-task verifier (Explore, VERDICT line) + final Observable-Truths verifier (Explore). ADD design rules: verifiers report, never repair; verdict gate precedes Final Validation; hooks check conditions, verifiers check claims. UPDATE §7 `/execute` entry ("Updates" gains: per-task verification verdicts). ADD to SKILL.md Guardrails: "**Never change scout/verifier prompt specs in a command without updating workflow.md §Subagent Layer** in the same change."
- **VALIDATE**: `grep -n 'verifier' template/.claude/workflow.md` → hits in §7 and §9; `grep -n 'Subagent Layer' template/.claude/skills/workflow/SKILL.md` → 1 hit
- **DONE**: docs lockstep complete

### RUN sync + validate (closes Phase B)

- **IMPLEMENT**: `./scripts/sync-template.sh`; battery.
- **VALIDATE**: `./.claude/hooks/validate-local.sh` → exit 0
- **DONE**: **Commit Phase B** (`feat(execute): post-task verification subagent`)

### CREATE .agents/learnings/level-2.md + walkthrough (Phase C — hard gate)

- **IMPLEMENT**: write per the PRD §7 learning-doc structure (gap → files → information flow → see-it-yourself → watch-outs → walkthrough log). Then the live walkthrough (Testing Strategy §Manual — the dogfood is real: the Level 3 plan gets produced by the new planner). Record sign-off comment on the Phase 2 epic. Only then may `/commit` close the epic.
- **VALIDATE**: doc exists; epic has sign-off comment
- **DONE**: Level 2 gate passed; Level 3 unblocked

---

## TESTING STRATEGY

### Unit Tests

No test framework (by design). The VALIDATE greps above are the structural unit tests — they assert the load-bearing prose exists (fan-out "single message" line, ≥3 subagent_type specs, VERDICT contract, intact deviation rules, balanced 4-backtick fences) after every edit and again after sync.

### Integration Tests

- **Fan-out live test**: run the new `/plan-feature` on the next real feature ("Level 3: weight-matched command variants") in a fresh session — observe three `Agent` calls in one message, three reports, synthesized plan containing an INTEGRATION CONTRACTS section
- **Verifier live test**: run `/execute` on a small task set; after one task, deliberately break the DONE artifact (e.g., remove a line the task added) before the verifier reports — observe `VERDICT: FAIL` with evidence, fix, re-verify, and only then Final Validation
- **Sync integrity**: `validate-local.sh` green; root copies byte-identical to template modulo placeholder fill

### Edge Cases

- Feature with zero external dependencies → external-research scout still runs but reports "nothing relevant" (≥3 scouts is unconditional; the report says so, the plan notes it)
- Single-component feature → contracts section is the explicit one-liner, not skipped
- Scout returns thin/no findings → synthesis notes the gap instead of inventing citations; main agent may do targeted follow-up reads itself
- Verifier VALIDATE command is mutating → verifier inspects artifacts only (the read-only/idempotent qualifier)
- A verifier never reports (crashed subagent) → the verdict gate blocks Final Validation; builder re-spawns that one verifier

### Manual Validation (= the Level 2 walkthrough script)

1. In a fresh session, run `/plan-feature "Level 3: weight-matched command variants"` — watch three scouts spawn in one message and run concurrently; read the synthesized plan's INTEGRATION CONTRACTS section
2. Diff the planner before/after: `git show <phase-A-sha> -- template/.claude/commands/plan-feature.md`
3. Run `/execute` on a small plan; watch a per-task verifier verdict arrive without the builder's context growing
4. Seed a defect (delete a just-created artifact line), watch `VERDICT: FAIL` + evidence + fix + re-verify
5. Attempt to reach Final Validation with a verdict outstanding — observe the gate hold
6. Read workflow.md §9 side-by-side with §8: conditions (hooks) vs claims (verifiers)

---

## VALIDATION COMMANDS

### Level 1: Syntax & Style

```bash
for f in scripts/*.sh .claude/hooks/*.sh .claude/scripts/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
grep -c '^````' template/.claude/commands/plan-feature.md   # expect 2 (fence upgraded, balanced)
```

### Level 2: Structural Contract Tests

```bash
grep -n 'single message' template/.claude/commands/plan-feature.md          # ≥1
grep -c 'subagent_type' template/.claude/commands/plan-feature.md           # ≥3
grep -n 'INTEGRATION CONTRACTS' template/.claude/commands/plan-feature.md   # in template fence
grep -c 'VERDICT' template/.claude/commands/execute.md                      # ≥2
grep -c 'Fix bugs inline' template/.claude/commands/execute.md              # 1 — deviation rules intact
grep -n 'Subagent Layer' template/.claude/workflow.md template/.claude/skills/workflow/SKILL.md
```

### Level 3: Integration

```bash
./scripts/sync-template.sh
./.claude/hooks/validate-local.sh && echo battery-green
grep -rl '{{' .claude/ | grep -v init-project.md | wc -l   # expect 0
```

### Level 4: Manual Validation

The walkthrough script above (Testing Strategy §Manual) — performed live with the owner as the Level 2 learning gate.

---

## ACCEPTANCE CRITERIA

- [ ] `/plan-feature` research runs ≥3 concurrent scouts spawned in a single message (PRD L2 req)
- [ ] Scout prompts are self-contained (feature restated; report format with file:line evidence demanded); ambiguity clarification happens before fan-out
- [ ] The plan template contains an INTEGRATION CONTRACTS section meeting the execute-team quality bar (exact URLs, explicit JSON shapes, events, errors, storage semantics, single-owner cross-cutting table, component boundaries); single-component plans state so explicitly
- [ ] Every `/execute` task is independently verified by a subagent; a seeded defect produces VERDICT: FAIL with evidence (PRD L2 req + Phase 2 validation)
- [ ] Verdict gate: Final Validation cannot start with outstanding or failed verdicts; final verifier checks plan-level Observable Truths
- [ ] Deviation rules, pre-flight, and report formats in `/execute` survive verbatim; no command renamed, no argument changed
- [ ] workflow.md §Subagent Layer added (§§ renumbered cleanly, no stale cross-references); §7 entries updated; SKILL.md guardrail added; sync green; no unresolved placeholders
- [ ] `.agents/learnings/level-2.md` written, walkthrough performed, owner sign-off recorded on the epic (**hard gate** — blocks Level 3)

## COMPLETION CHECKLIST

- [ ] All tasks completed in order (A → B → C)
- [ ] Every VALIDATE line executed and passing, after edit and after sync
- [ ] Both commits made (Phase A: feat(plan-feature), Phase B: feat(execute)) — epic stays open until Phase C sign-off
- [ ] Fan-out and verifier observed live (walkthrough), not just structurally
- [ ] Learning gate passed — owner sign-off on epic

---

## NOTES

- **Why clarification moves before fan-out**: the current command clarifies *after* codebase research; with paid-for parallel scouts, an ambiguity discovered post-fan-out invalidates their work. Judgment (asking) precedes retrieval (scouting). Scouts may still surface new ambiguities — those get raised at synthesis.
- **Why the verifier is Explore**: read-only by construction (report-don't-repair is enforced by tooling, not prose), cheap, no CLAUDE.md load. The builder stays the only writer — no worktree/conflict story needed until Level 4.
- **Hooks vs verifiers** (the Level 2 conceptual line): Level 1 hooks check deterministic *conditions* (lint, tsc, drift). Level 2 verifiers check *claims* (VERIFY/DONE, Observable Truths) — judgment work, hence an agent, not a script. Neither replaces the other.
- **Scope exclusions**: executor recommendation in plans ("this plan suits /execute-team") is Level 3 scope — the contracts section lands now, the routing advice later. Porting `/execute-team` itself is Level 3. No changes to `/continue`, `/status`, `/commit`, init-project, hooks, or scripts.
- **KISS check**: no new files in template/, no new scripts, no orchestration machinery — two command rewrites + docs. The simplest version of "scale compute" that works.
- **Fence upgrade risk**: the 4-backtick outer fence is the one mechanically fragile edit — validate fence balance immediately after that task, not just at sync time.
- **Dogfood sequencing**: this repo's root copy updates at sync, but the *session* that implements Level 2 was primed with the old planner. The first real execution of the new machinery is the Phase C walkthrough (planning Level 3) — which is exactly what the PRD's Phase 2 validation prescribes.
