# Level 2: Parallel Subagents — What Changed and Why

**Status:** complete — walkthrough performed and owner sign-off recorded on epic #10 (2026-07-14)
**Commits:** `c41c9c3` (Phase A: /plan-feature scouts + Integration Contracts), `1ce1417` (Phase B: /execute verifier)

---

## The gap this closes

Before Level 2, `/plan-feature` was one agent doing everything serially — the same context window that read the board also grepped the codebase, fetched external docs, and wrote the plan. Research detail competed with synthesis for attention, and wall-clock time was the sum of every phase. And `/execute` graded its own homework: Level 1's hooks catch deterministic failures (lint, tsc, drift), but nothing independently checked that a task's *claimed outcome* actually held. AGENTIC-EVOLUTION.md calls this Level 2: **"Scale compute to scale impact"** — Dan's scout/researcher split and his test-agent, done inside one session with the native `Agent` tool. Zero API cost; the parallelism is subscription-native.

## What changed, file by file

### `/plan-feature` (template/.claude/commands/plan-feature.md)

| Before | After |
|---|---|
| Phase 2 "Codebase Intelligence" — serial checklist the main agent worked through | Phase 2 "Clarify Ambiguities" — moved *before* any scout spend (asking after the fan-out wastes their work) |
| Phase 3 "External Research" — more serial checklist | Phase 3 "Parallel Intelligence Gathering" — three scouts spawned as `Agent` calls **in a single message**: codebase-patterns (`Explore`), external-research (`general-purpose`), testing-patterns (`Explore`) |
| Phase 4 "Deep Strategic Thinking" | Phase 4 "Synthesis & Deep Strategic Thinking" — wait for all three reports, cross-check them, **spot-check load-bearing file:line claims**, surface new ambiguities; then the original strategic-thinking content unchanged |

The load-bearing line is *"in a single message"* — subagents listed as sequential steps get executed sequentially. The second load-bearing rule: **subagents see none of the conversation**, so each scout prompt restates the feature, constraints, and required report format in full.

### The plan template: `## INTEGRATION CONTRACTS`

New section between CONTEXT REFERENCES and OBSERVABLE TRUTHS. For multi-component features it is the authoritative interface definition, built to the `execute-team` quality bar (that skill arrives from nexus at Level 3 — this is its dependency, landed early per PRD decision #7):

1. URLs exact, **including trailing slashes**
2. Data shapes as **explicit JSON, not prose**, flat-vs-nested called out
3. Event/streaming types as exact JSON
4. Error bodies per failure mode
5. State/storage semantics explicit

Plus component ownership boundaries (owns / must-not-touch) and a cross-cutting-concerns table where every concern has **exactly one owner**. Single-component features write one line: "Single-component feature — no cross-component contracts." (This level's own plan did exactly that.)

Mechanical detail that mattered: the plan template lives inside a fenced block, and the contracts section needs JSON fences *inside* it — so the outer fence was upgraded to **four backticks**. Nested fences are the one way this file breaks silently.

### `/execute` (template/.claude/commands/execute.md)

- **Step 3c (new): spawn the task verifier.** After a task's VALIDATE passes, an `Explore` subagent gets the task block, the touched file paths, and the related Observable Truths — and is told: *don't trust the builder; read the artifacts; answer `VERDICT: PASS` or `VERDICT: FAIL — evidence`.* The builder may continue to the next task while verifiers run in the background.
- **Step 5: verdict gate.** Final Validation cannot begin until every verifier has reported and every FAIL is fixed and re-verified.
- **Step 6: final Observable-Truths verifier.** One last `Explore` agent independently confirms every plan-level Observable Truth before the report may claim "Ready for Commit".
- Deviation rules, pre-flight, and the report format survived verbatim; the report gained a "Verification" subsection (verdicts are part of the record now).

### workflow.md §9 "Subagent Layer" + skill guardrail

The system doc gained a section mirroring §8 Hook Layer: the five-subagent roster, the design rules, and the contracts quality bar. Old §9–11 renumbered to §10–12 (no cross-references existed — checked). The workflow skill gained the lockstep guardrail: *never change a scout/verifier prompt spec without updating §Subagent Layer in the same change.*

## How information flows now

```
BEFORE                                     AFTER
/plan-feature                              /plan-feature
  board → understand → grep codebase         board → understand → CLARIFY
  → fetch docs → find tests → think          → ┌─ scout: codebase patterns ─┐
  → write plan                                 ├─ scout: external research ─┤ (one message,
  (one context, serial, ~sum of phases)       └─ scout: testing patterns ──┘  concurrent)
                                             → synthesize (spot-check claims) → write plan

/execute task loop                         /execute task loop
  implement → VALIDATE → next task           implement → VALIDATE → spawn verifier ─┐
  (builder grades itself)                    → next task            (background)    │
                                             ...                                    ▼
                                             VERDICT gate ← every PASS required ────┘
                                             → Final Validation → Observable-Truths verifier → report
```

The conceptual line to keep: **Level 1 hooks check *conditions*** (deterministic pass/fail — lint, tsc, drift; the harness fires them). **Level 2 verifiers check *claims*** (does the artifact actually do what the task said — judgment, so it's an agent). Neither replaces the other.

## See it yourself (the walkthrough script)

1. In a **fresh session**, run `/plan-feature "Level 3: weight-matched command variants"` — watch three `Agent` calls appear in one message and run concurrently; read the produced plan's INTEGRATION CONTRACTS section. (This is the real Level 3 prep, not a toy — the PRD's Phase 2 validation.)
2. `git show c41c9c3 -- template/.claude/commands/plan-feature.md` — the before/after of the fan-out.
3. Run `/execute` on a small plan; watch a per-task `VERDICT: PASS` arrive without the builder's context filling with verifier exploration.
4. **Seed a defect:** after a task completes, delete a line the task added, then let the verifier run — watch `VERDICT: FAIL — <file:line evidence>`, the fix, and the re-verify.
5. Try to reach Final Validation with a verdict outstanding — the command's gate holds it.
6. Read workflow.md §8 and §9 side by side: conditions vs claims.

## What to watch out for

- **Serialization regression:** if a future edit rewrites the fan-out as numbered steps ("First spawn scout 1..."), parallelism silently dies. The "single message" sentence is the contract; the workflow skill guardrail exists to protect it.
- **Context leakage assumption:** scouts/verifiers know *nothing* you didn't put in their prompt. Symptoms of forgetting: a scout researching the wrong feature, a verifier passing trivially because it wasn't told what to check.
- **Verifier races:** verifiers run in the background while the builder edits ahead. Each verifier prompt pins the exact files/claims of *its* task, so unrelated later edits don't confuse it. Don't widen a verifier's scope mid-run.
- **Mutating VALIDATE commands:** verifiers only re-run a task's VALIDATE if it's read-only/idempotent (migrations and installs are not). They verify by inspection otherwise.
- **Scout hallucination pressure:** a scout with thin findings may pad. The synthesis rule ("note the gap instead of inventing citations" + spot-check load-bearing claims) is the countermeasure — keep it.
- **Cost:** every /plan-feature now spends 3 subagent contexts and /execute spends ~1 per task. That's the deliberate trade (compute for quality/speed). Level 3's light variants (/chore, /hotfix) exist precisely so small work can skip this weight.
- **Escape hatch:** none needed at the harness level — this is all command prose. Ignore-in-place is not possible for an agent following the command, but you can always run the old flow by reverting the two commits.

## Interesting findings from the build

1. **The nexus contract extraction paid off:** the `execute-team` skill has no literal "Integration Contracts" heading requirement — it checks *content* (endpoints table, JSON shapes, cross-cutting owners). The template section was therefore built to the skill's quality-bar checklist, not to a heading convention. When the skill is ported at Level 3, its "read it, confirm it's complete" step should find everything where it expects.
2. **Nested-fence hazard was real:** the plan template's outer ```` ```markdown ```` fence would have been terminated by the first ```json example inside the contracts section. Four-backtick outer fence fixed it; `grep -c '^````'` → 2 is now part of the validation battery for this file.
3. **The machinery verified its own build:** Phase B shipped the Observable-Truths verifier, and this execution then *used* it — an Explore verifier independently confirmed all 7 structural truths (fences, section presence, deviation-rule survival, sync integrity, 9-command roster) before the report was written. First live fire of the new step 6, on the change that created it.
4. **Plan-vs-battery placeholder scope:** the plan's raw `grep -rl '{{' .claude/` validation expected 0 hits but found 2 — both the documented Level 1 exceptions (PRD.md mentions placeholder syntax in prose; validate-local.sh contains its own grep pattern). The battery's generated-files-only scope is the authoritative check. Lesson repeated from Level 1: validation layers must account for their own reflection.

## Walkthrough log (2026-07-14, live)

1. **Scout fan-out fired twice, once in each of two parallel sessions.** The owner ran the new `/plan-feature "Level 3: weight-matched command variants"` in a fresh session — three concurrent scouts, a full plan with Integration Contracts (`.agents/plans/level-3-weight-matched-command-variants.md`), and epic #16 + six task sub-issues created through `create-issue.sh`. Simultaneously, the walkthrough session ran the same fan-out as a demo: three `Agent` calls in one message, three file:line-cited reports (codebase scout produced a 13-point add-a-command integration checklist and caught that `type:chore`/`type:hotfix` labels don't exist — a High-Stakes taxonomy change for Level 3; external scout verified agent-teams is still experimental, `TeamCreate`/`TeamDelete` were removed in v2.1.178, and file ownership is convention not enforcement; testing scout mapped exactly which validation tiers a new `.md` command is subject to). PRD Phase 2 validation — "plan produced by parallel scouts on a real Level 3 prep issue" — satisfied by the owner's own run.
2. **Seeded defect → verifier catch.** The SKILL.md Subagent Layer guardrail was deleted and synced — a defect invisible to every hook (consistent tree, valid syntax). The task verifier independently re-ran the task's VALIDATE grep and returned `VERDICT: FAIL` citing the missing entry at SKILL.md:140–147 in both the template and root copies. Fix → re-verify → `VERDICT: PASS`; tree back to matching HEAD. The conditions-vs-claims line demonstrated exactly.
3. **Accidental Level 5 preview.** Two sessions worked the repo simultaneously — planner in one, walkthrough in the other — coordinated only by the board and git, zero conflicts. The "board as shared blackboard" convention works before it's even formalized.
4. **Attribution lesson (walkthrough-session error, corrected by the owner).** The walkthrough session noticed the Level 3 plan file appear mid-run and misattributed it to the `general-purpose` scout (the one subagent type with write tools). The owner corrected the record: they had written it in their parallel session. Lesson: an artifact appearing mid-run needs a provenance check before a conclusion — especially once multiple sessions are in play. The plausible-but-false failure mode still motivated a cheap real guard: scout prompts now explicitly forbid file creation ("scouts are read-only by contract", commit `71d0f6c`), the prompt-level twin of the verifiers' tooling-enforced report-don't-repair.

**Sign-off:** recorded 2026-07-14 as the closing comment on epic #10.
